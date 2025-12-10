<?php
// www/register.php
require_once 'db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: /');
    exit;
}

$fullname = trim($_POST['fullname'] ?? '');
$email = trim($_POST['email'] ?? '');
$roll = trim($_POST['roll'] ?? '');

if ($fullname === '' || $email === '' || $roll === '') {
    echo "Please fill all fields.";
    exit;
}

// prepared insert
$stmt = $mysqli->prepare("INSERT INTO students (fullname, email, roll) VALUES (?, ?, ?)");
if (!$stmt) {
    die("Prepare failed: " . $mysqli->error);
}
$stmt->bind_param('sss', $fullname, $email, $roll);
$ok = $stmt->execute();
if ($ok) {
    echo "Registered successfully. <a href='/'>Back</a>";
} else {
    echo "Error: " . htmlspecialchars($stmt->error);
}
$stmt->close();
$mysqli->close();
