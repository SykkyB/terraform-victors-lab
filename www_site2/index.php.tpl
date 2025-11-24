<?php
// ---------------------------
// PostgreSQL Connection
// ---------------------------
$db_host = "${db_host}";
$db_name = "${db_name}";
$db_user = "${db_user}";
$db_pass = "${db_pass}";
$db_port = "5432";

$conn_string = "host=$db_host port=$db_port dbname=$db_name user=$db_user password=$db_pass";

$db_conn = pg_connect($conn_string);

if (!$db_conn) {
    $db_status = "❌ Failed to connect to Postgres DB.";
} else {
    $db_status = "✅ Postgres DB connected successfully.";
}

// ---------------------------
// Fetch Latest Crypto Rates
// ---------------------------
$latest_text = "No data available.";

if ($db_conn) {
    $query = "
        SELECT *
        FROM crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        LIMIT 1;
    ";

    $result = pg_query($db_conn, $query);

    if ($result && pg_num_rows($result) > 0) {
        $row = pg_fetch_assoc($result);

        $latest_text = "
            <table border='1' cellpadding='8' cellspacing='0' style='border-collapse: collapse; width: 100%; text-align: center;'>
                <thead>
                    <tr style='background: #eef7ff;'>
                        <th>Date</th>
                        <th>Time</th>
                        <th>BTC/USD</th>
                        <th>ETH/USD</th>
                        <th>SOL/USD</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>{$row['rate_date']}</td>
                        <td>{$row['rate_time']}</td>
                        <td>{$row['btc_usd']}</td>
                        <td>{$row['eth_usd']}</td>
                        <td>{$row['sol_usd']}</td>
                    </tr>
                </tbody>
            </table>
        ";
    }
}
?>
