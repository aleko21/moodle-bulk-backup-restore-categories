#!/usr/bin/env php
<?php
define('CLI_SCRIPT', true);

require(__DIR__ . '/../../config.php');
require_once($CFG->libdir . '/clilib.php');
require_once($CFG->dirroot . '/backup/util/includes/restore_includes.php');
require_once($CFG->dirroot . '/course/lib.php');
require_once($CFG->libdir . '/filelib.php');

list($options, $unrecognized) = cli_get_params(
    [
        'help' => false,
        'file' => null,
        'categoryid' => null,
        'showdebugging' => false,
    ],
    [
        'h' => 'help',
    ]
);

if (!empty($unrecognized)) {
    cli_error('Unknown options: ' . implode(', ', $unrecognized));
}

if (!empty($options['help']) || empty($options['file']) || empty($options['categoryid'])) {
    $help = <<<EOT
Restore a Moodle .mbz backup into a NEW course in the specified category,
attempting to exclude users and user-related data.

Options:
--file=PATH            Full path to .mbz backup file
--categoryid=ID        Destination category id
--showdebugging        Enable verbose PHP/Moodle debugging
-h, --help             Show this help

Example:
php admin/cli/restore_backup_nousers.php \
  --file="/path/to/backup.mbz" \
  --categoryid=29 \
  --showdebugging
EOT;
    echo $help . PHP_EOL;
    exit(0);
}

if (!empty($options['showdebugging'])) {
    error_reporting(E_ALL);
    ini_set('display_errors', '1');
    ini_set('display_startup_errors', '1');
    $CFG->debug = E_ALL;
    $CFG->debugdisplay = 1;
}

$file = $options['file'];
$categoryid = (int)$options['categoryid'];

if (!is_readable($file)) {
    cli_error("Backup file not readable: {$file}");
}

if (!preg_match('/\.mbz$/i', $file)) {
    cli_error("Input file does not look like a Moodle backup (.mbz): {$file}");
}

if (!$DB->record_exists('course_categories', ['id' => $categoryid])) {
    cli_error("Category not found: {$categoryid}");
}

$admin = get_admin();
if (!$admin) {
    cli_error('Admin user not found.');
}
\core\session\manager::set_user($admin);

$backupdir = 'restore_' . uniqid('', true);
$backuppath = $CFG->tempdir . DIRECTORY_SEPARATOR . 'backup' . DIRECTORY_SEPARATOR . $backupdir;

if (!check_dir_exists($backuppath, true, true)) {
    cli_error("Unable to create temp backup directory: {$backuppath}");
}

echo "== Extracting backup to: {$backuppath} ==" . PHP_EOL;

try {
    $packer = get_file_packer('application/vnd.moodle.backup');
    $packer->extract_to_pathname($file, $backuppath);
} catch (Throwable $e) {
    fulldelete($backuppath);
    cli_error('Failed to extract backup: ' . $e->getMessage());
}

try {
    list($fullname, $shortname) = restore_dbops::calculate_course_names(
        0,
        get_string('restoringcourse', 'backup'),
        get_string('restoringcourseshortname', 'backup')
    );

    $courseid = restore_dbops::create_new_course($fullname, $shortname, $categoryid);

    echo "== Created target course ID: {$courseid} ==" . PHP_EOL;

    $rc = new restore_controller(
        $backupdir,
        $courseid,
        backup::INTERACTIVE_NO,
        backup::MODE_GENERAL,
        $admin->id,
        backup::TARGET_NEW_COURSE
    );

    $plan = $rc->get_plan();

    try {
        $usersetting = $plan->get_setting('users');
        if ($usersetting) {
            $usersetting->set_value(false);
            echo "== Setting users=false ==" . PHP_EOL;
        } else {
            echo "== Warning: setting 'users' not found in restore plan ==" . PHP_EOL;
        }
    } catch (Throwable $e) {
        echo "== Warning: unable to set users=false ({$e->getMessage()}) ==" . PHP_EOL;
    }

    $optionalsettings = [
        'role_assignments',
        'groups',
        'groupings',
        'comments',
        'logs',
        'userscompletion',
        'grade_histories',
        'activitiescompletion',
        'calendar_events',
    ];

    foreach ($optionalsettings as $settingname) {
        try {
            $setting = $plan->get_setting($settingname);
            if ($setting) {
                $setting->set_value(false);
                echo "== Setting {$settingname}=false ==" . PHP_EOL;
            }
        } catch (Throwable $e) {
            // Ignore missing settings.
        }
    }

    echo "== Running precheck ==" . PHP_EOL;
    $precheck = $rc->execute_precheck();

    if (!$precheck) {
        echo "== Precheck failed. Details: ==" . PHP_EOL;
        print_r($rc->get_precheck_results());
        $rc->destroy();
        fulldelete($backuppath);
        cli_error('Restore precheck failed.');
    }

    echo "== Executing restore ==" . PHP_EOL;
    $rc->execute_plan();
    $rc->destroy();

    echo "== Cleaning temporary files ==" . PHP_EOL;
    fulldelete($backuppath);

    echo "Restore completed successfully. New course ID: {$courseid}" . PHP_EOL;
    exit(0);

} catch (Throwable $e) {
    if (isset($rc)) {
        try {
            $rc->destroy();
        } catch (Throwable $ignored) {
        }
    }

    if (is_dir($backuppath)) {
        fulldelete($backuppath);
    }

    cli_error('Restore failed: ' . $e->getMessage());
}
