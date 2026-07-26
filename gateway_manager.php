<?php
header('Content-Type: application/json');

$action  = $_GET['action'] ?? '';
$gateway = preg_replace('/[^0-9A-Za-z_\-]/', '', $_GET['gateway'] ?? '');

function runFS($cmd)
{
    $output = [];
    $return = 0;
    exec("/usr/bin/fs_cli -x \"$cmd\" 2>&1", $output, $return);

    return [
        'return_code' => $return,
        'output'      => $output
    ];
}

switch ($action) {

    // Reload gateway configuration
    case 'rescan':

        $result = runFS('sofia profile external rescan');

        echo json_encode([
            'success' => ($result['return_code'] == 0),
            'action'  => 'rescan',
            'result'  => $result
        ], JSON_PRETTY_PRINT);

        break;


    // Check gateway registration status
    case 'status':

        if (empty($gateway)) {
            exit(json_encode([
                'success' => false,
                'message' => 'gateway parameter required'
            ], JSON_PRETTY_PRINT));
        }

        $result = runFS("sofia status gateway $gateway");

        $status = "UNKNOWN";

        foreach ($result['output'] as $line) {

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
            'status'  => $status,
            'result'  => $result
        ], JSON_PRETTY_PRINT);

        break;


    // Retry registration
    case 'retry':

        if (empty($gateway)) {
            exit(json_encode([
                'success' => false,
                'message' => 'gateway parameter required'
            ], JSON_PRETTY_PRINT));
        }

        $kill = runFS("sofia profile external killgw $gateway");

        sleep(2);

        $rescan = runFS("sofia profile external rescan");

        sleep(2);

        $status = runFS("sofia status gateway $gateway");

        echo json_encode([
            'success' => true,
            'gateway' => $gateway,
            'killgw'  => $kill,
            'rescan'  => $rescan,
            'status'  => $status
        ], JSON_PRETTY_PRINT);

        break;


    default:

        echo json_encode([
            'success' => false,
            'message' => 'Invalid action',
            'available_actions' => [
                'rescan',
                'status',
                'retry'
            ]
        ], JSON_PRETTY_PRINT);

}
