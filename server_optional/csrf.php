<?php
declare(strict_types=1);
define('ATX_SKIP_ACCESS_GUARD', true);
require_once __DIR__ . '/../../app/bootstrap.php';
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    atx_json(false, 'Metodo non consentito', [], 405);
}
atx_json(true, '', ['csrf' => atx_csrf_token()]);
