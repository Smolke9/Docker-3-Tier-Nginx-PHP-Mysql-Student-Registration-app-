<?php
// www/db.php
$DB_HOST = getenv('DB_HOST') ?: 'mysql';
$DB_NAME = getenv('DB_NAME') ?: 'studentdb';
$DB_USER = getenv('DB_USER') ?: 'studentuser';
$DB_PASS = getenv('DB_PASS') ?: 'studentpass';
$DB_PORT = getenv('DB_PORT') ?: '3306';

$mysqli = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME, (int)$DB_PORT);
if ($mysqli->connect_error) {
    die("DB connection failed: " . $mysqli->connect_error);
}

// set charset
$mysqli->set_charset("utf8mb4");
