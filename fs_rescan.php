<?php
header('Content-Type: application/json');

$output = [];
$return = 0;

exec('/usr/bin/fs_cli -x "sofia profile external rescan" 2>&1', $output, $return);

echo json_encode([
    'success' => ($return == 0),
    'command' => 'sofia profile external rescan',
    'return_code' => $return,
    'output' => $output
], JSON_PRETTY_PRINT);
