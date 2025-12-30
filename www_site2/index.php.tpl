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

date_default_timezone_set('Asia/Tbilisi');

// ---------------------------
// Helper functions
// ---------------------------
function format_rate($value) {
    return rtrim(rtrim(number_format((float)$value, 8, '.', ''), '0'), '.');
}

// ---------------------------
// Init vars
// ---------------------------
$db_status = "";
$latest_text = "";
$history_text = "";
$chart_data = [];

// ---------------------------
// DB logic
// ---------------------------
if (!$db_conn) {
    $db_status = "❌ Failed to connect to Postgres DB: " . pg_last_error();
} else {
    $db_status = "✅ Postgres DB connected successfully.";

    // ---------------------------
    // Latest rate
    // ---------------------------
    $query_latest = "
        SELECT *
        FROM public.crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        LIMIT 1;
    ";
    $result_latest = pg_query($db_conn, $query_latest);

    if ($result_latest && pg_num_rows($result_latest) > 0) {
        $row = pg_fetch_assoc($result_latest);

        $latest_text = "
            <div class='db-box'>
                <h2>Latest Crypto Rates</h2>
                <table>
                    <thead>
                        <tr>
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
                            <td class='utc-time'
                                data-date=\"{$row['rate_date']}\"
                                data-time=\"{$row['rate_time']}\">
                                {$row['rate_time']}
                            </td>
                            <td>" . format_rate($row['btc_usd']) . "</td>
                            <td>" . format_rate($row['eth_usd']) . "</td>
                            <td>" . format_rate($row['sol_usd']) . "</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        ";
    }

    // ---------------------------
    // Chart data (last 24h)
    // ---------------------------
    $query_chart = "
        SELECT rate_date, rate_time, btc_usd, eth_usd, sol_usd
        FROM public.crypto_rates
        WHERE (rate_date + rate_time) >= (NOW() - INTERVAL '24 hours')
        ORDER BY rate_date, rate_time;
    ";

    $result_chart = pg_query($db_conn, $query_chart);

    if ($result_chart) {
        while ($row = pg_fetch_assoc($result_chart)) {
            $dt = new DateTime(
                $row['rate_date'] . ' ' . substr($row['rate_time'], 0, 8),
                new DateTimeZone("UTC")
            );
            $dt->setTimezone(new DateTimeZone("Asia/Tbilisi"));

            $chart_data[] = [
                "time" => $dt->format("H:i"),
                "btc"  => (float)$row['btc_usd'],
                "eth"  => (float)$row['eth_usd'],
                "sol"  => (float)$row['sol_usd'],
            ];
        }
    }

    // ---------------------------
    // History (previous 10)
    // ---------------------------
    $query_history = "
        SELECT *
        FROM public.crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        OFFSET 1
        LIMIT 10;
    ";

    $result_history = pg_query($db_conn, $query_history);

    if ($result_history && pg_num_rows($result_history) > 0) {
        $history_text = "
            <div class='db-box'>
                <h2>Exchange Rate History (Previous 10 Records)</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Time</th>
                            <th>BTC/USD</th>
                            <th>ETH/USD</th>
                            <th>SOL/USD</th>
                        </tr>
                    </thead>
                    <tbody>
        ";

        while ($row = pg_fetch_assoc($result_history)) {
            $history_text .= "
                <tr>
                    <td>{$row['rate_date']}</td>
                    <td class='utc-time'
                        data-date=\"{$row['rate_date']}\"
                        data-time=\"{$row['rate_time']}\">
                        {$row['rate_time']}
                    </td>
                    <td>" . format_rate($row['btc_usd']) . "</td>
                    <td>" . format_rate($row['eth_usd']) . "</td>
                    <td>" . format_rate($row['sol_usd']) . "</td>
                </tr>
            ";
        }

        $history_text .= "</tbody></table></div>";
    }

    pg_close($db_conn);
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Crypto Rates Dashboard</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
body {
    font-family: Arial, sans-serif;
    background: #f4f4f4;
    padding: 40px;
}
.container {
    background: #fff;
    max-width: 900px;
    margin: auto;
    padding: 30px;
    border-radius: 12px;
}
.db-box {
    background: #eef7ff;
    padding: 20px;
    border-radius: 10px;
    margin-top: 25px;
}
table {
    width: 100%;
    border-collapse: collapse;
}
th, td {
    padding: 8px;
    border: 1px solid #ccc;
    text-align: center;
}
th {
    background: #ddeeff;
}
</style>
</head>

<body>
<div class="container">

<img src="<?= "${cloudfront_url}web_site2/images/crypto.jpg" ?>" style="max-width:100%;border-radius:10px">

<h1>Crypto Rates Dashboard</h1>
<p>EC2 → RDS PostgreSQL → Terraform-managed infra</p>

<div class="db-box"><strong>DB Status:</strong> <?= $db_status ?></div>

<?= $latest_text ?>

<!-- 🔥 GRAPH AFTER LATEST -->
<div class="db-box">
    <h2>Crypto Rates – Last 24 Hours</h2>
    <canvas id="cryptoChart" height="120"></canvas>
</div>

<?= $history_text ?>

</div>

<script>
document.addEventListener("DOMContentLoaded", function () {

    // Convert UTC time in tables
    document.querySelectorAll(".utc-time").forEach(cell => {
        const d = cell.dataset.date;
        const t = cell.dataset.time.substring(0,8);
        const dt = new Date(d + "T" + t + "Z");
        cell.textContent = dt.toLocaleTimeString();
    });

    // Chart
    const data = <?= json_encode($chart_data); ?>;

    const labels = data.map(p => p.time);

    new Chart(document.getElementById("cryptoChart"), {
        type: "line",
        data: {
            labels,
            datasets: [
                { label: "BTC/USD", data: data.map(p=>p.btc), borderColor:"#f7931a", tension:0.3 },
                { label: "ETH/USD", data: data.map(p=>p.eth), borderColor:"#3c3c3d", tension:0.3 },
                { label: "SOL/USD", data: data.map(p=>p.sol), borderColor:"#00ffa3", tension:0.3 }
            ]
        },
        options: {
            responsive: true,
            interaction: { mode: "index", intersect: false },
            scales: { x: { ticks: { maxTicksLimit: 12 } } }
        }
    });
});
</script>

</body>
</html>
