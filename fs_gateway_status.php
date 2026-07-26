<?php
header('Content-Type: application/json');

$gateway = $_GET['gateway'] ?? '';

if (!$gateway) {
    die(json_encode([
        'success' => false,
        'message' => 'gateway parameter required'
    ]));
}

$output = [];
$return = 0;

exec('/usr/bin/fs_cli -x "sofia status gateway ' . escapeshellarg($gateway) . '" 2>&1', $output, $return);

$status = 'UNKNOWN';

foreach ($output as $line) {
    if (stripos($line, 'REGED') !== false)
        $status = 'REGISTERED';

    if (stripos($line, 'NOREG') !== false)
        $status = 'NOT_REGISTERED';

    if (stripos($line, 'FAILED') !== false)
        $status = 'FAILED';

    if (stripos($line, 'UNREGED') !== false)
        $status = 'UNREGISTERED';
}

echo json_encode([
    'success' => true,
    'gateway' => $gateway,
    'status' => $status,
    'output' => $output
], JSON_PRETTY_PRINT);
