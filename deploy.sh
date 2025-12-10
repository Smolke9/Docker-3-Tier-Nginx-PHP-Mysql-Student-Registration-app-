#!/bin/bash
set -e

echo "========== Updating server =========="
sudo apt update && sudo apt upgrade -y

echo "========== Installing docker & docker-compose =========="
sudo apt install -y docker.io docker-compose
sudo systemctl enable --now docker

echo "========== Adding user to docker group =========="
sudo usermod -aG docker $USER

echo "========== Creating project folders =========="
mkdir -p ~/student-app/www
mkdir -p ~/student-app/nginx
mkdir -p ~/student-app/mysql-init
mkdir -p ~/student-app/mysql-data

##############################################
# Writing index.html
##############################################
cat << 'EOF' > ~/student-app/www/index.html
<!DOCTYPE html>
<html>
<head>
<title>Student Register</title>

<style>

/* Background */
body {
    font-family: Arial, sans-serif;
    background: linear-gradient(135deg, #1a1a1a, #333);
    color: white;
    margin: 0;
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
}

/* Heading at top center */
.title {
    text-align: center;
    position: absolute;
    top: 20px;
    width: 100%;
}

.title h2 {
    color: cyan;
    font-size: 32px;
    text-shadow: 0 0 12px cyan;
}

/* Form box */
form {
    background: #222;
    padding: 25px;
    border-radius: 12px;
    width: 330px;
    box-shadow: 0 0 15px rgba(0,255,255,0.4);
    margin-top: 40px;
}

/* Input fields */
input {
    width: 95%;
    padding: 10px;
    margin-top: 6px;
    margin-bottom: 15px;
    border-radius: 6px;
    border: none;
    outline: none;
    font-size: 16px;
    background: #111;
    color: white;
    box-shadow: 0px 0px 6px #00ffff66;
}

/* RGB glowing button */
button {
    width: 100%;
    padding: 12px;
    font-size: 18px;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    color: white;
    background: linear-gradient(90deg, red, blue, green);
    background-size: 300%;
    animation: rgbGlow 3s infinite;
    box-shadow: 0px 0px 10px cyan;
}

/* RGB animation */
@keyframes rgbGlow {
    0% { background-position: 0%; }
    50% { background-position: 100%; }
    100% { background-position: 0%; }
}

button:hover {
    box-shadow: 0 0 20px cyan;
    transform: scale(1.05);
}

</style>

</head>

<body>

<!-- Heading -->
<div class="title">
    <h2>Student Registration</h2>
    <strong>SURAJ MOLKE</strong><br>
    Pune, Maharashtra<br>
    <a href="mailto:smolke9@gmail.com">smolke9@gmail.com</a><br>
    <a href="https://github.com/Smolke9" target="_blank">GitHub</a> |
    <a href="https://www.linkedin.com/in/suraj-molke-4656002a6/" target="_blank">LinkedIn</a>
</div>

<!-- Form -->
<form action="register.php" method="POST">
    Name:
    <input type="text" name="fullname" required>

    Email:
    <input type="email" name="email" required>

    Roll No:
    <input type="text" name="roll" required>

    <button type="submit">Submit</button>
</form>

</body>
</html>
EOF

##############################################
# Writing db.php
##############################################
cat << 'EOF' > ~/student-app/www/db.php
<?php
$mysqli = new mysqli("mysql", "studentuser", "studentpass", "studentdb");

if ($mysqli->connect_error) {
    die("DB Connection failed: " . $mysqli->connect_error);
}
?>
EOF

##############################################
# Writing register.php
##############################################
cat << 'EOF' > ~/student-app/www/register.php
<?php
require "db.php";

$fullname = $_POST['fullname'];
$email = $_POST['email'];
$roll = $_POST['roll'];

$stmt = $mysqli->prepare("INSERT INTO students(fullname,email,roll) VALUES (?,?,?)");
$stmt->bind_param("sss", $fullname, $email, $roll);

if ($stmt->execute()) {
    echo "Student Registered Successfully!";
} else {
    echo "Error: " . $stmt->error;
}
?>
EOF

##############################################
# Writing init.sql
##############################################
cat << 'EOF' > ~/student-app/mysql-init/init.sql
CREATE DATABASE IF NOT EXISTS studentdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'studentuser'@'%' IDENTIFIED BY 'studentpass';
GRANT ALL PRIVILEGES ON studentdb.* TO 'studentuser'@'%';
FLUSH PRIVILEGES;

USE studentdb;

CREATE TABLE IF NOT EXISTS students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fullname VARCHAR(255),
  email VARCHAR(255),
  roll VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

##############################################
# Writing Nginx config
##############################################
cat << 'EOF' > ~/student-app/nginx/default.conf
server {
    listen 80;
    root /var/www/html;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php-fpm:9000;
        fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
    }
}
EOF

echo "========== Creating Docker networks =========="
docker network create frontend || true
docker network create backend || true

echo "========== Starting MySQL container =========="
docker run -d \
  --name mysql \
  --network backend \
  -e MYSQL_ROOT_PASSWORD=rootpass123 \
  -v ~/student-app/mysql-data:/var/lib/mysql \
  -v ~/student-app/mysql-init:/docker-entrypoint-initdb.d \
  mysql:8.0

echo "========== Starting PHP-FPM container =========="
docker run -d \
  --name php-fpm \
  -v ~/student-app/www:/var/www/html \
  php:8.1-fpm bash -c "docker-php-ext-install mysqli && php-fpm"

echo "========== Connecting PHP container to networks =========="
docker network connect frontend php-fpm
docker network connect backend php-fpm

echo "========== Starting Nginx container =========="
docker run -d \
  --name nginx \
  --network frontend \
  -p 80:80 \
  -v ~/student-app/www:/var/www/html:ro \
  -v ~/student-app/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx

echo "==================================================="
echo " Deployment Completed Successfully!"
echo " Open your browser:  http://<server-ip>"
echo "==================================================="