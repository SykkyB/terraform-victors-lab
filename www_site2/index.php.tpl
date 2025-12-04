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

function format_time($date_str, $time_str) {
    // Combine DATE + TIME from DB
    $dt = new DateTime("$date_str $time_str", new DateTimeZone("UTC"));
    // Convert to your timezone
    $dt->setTimezone(new DateTimeZone("Asia/Tbilisi"));
    return $dt->format("H:i:s");
}

// ---------------------------
// Fetch Latest Crypto Rates
// ---------------------------
if (!$db_conn) {
    $db_status = "❌ Failed to connect to Postgres DB: " . pg_last_error();
    $latest_text = "";
    $history_text = "";
} else {
    $db_status = "✅ Postgres DB connected successfully.";

    // Latest rate
    $query_latest = "
        SELECT *
        FROM public.crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        LIMIT 1;
    ";
    $result_latest = pg_query($db_conn, $query_latest);

    if (!$result_latest) {
        $latest_text = "Query failed: " . pg_last_error();
    } elseif (pg_num_rows($result_latest) == 0) {
        $latest_text = "No crypto rates found.";
    } else {
        $row = pg_fetch_assoc($result_latest);
        $latest_text = "
            <div class='db-box'>
                <h2>Latest Crypto Rates</h2>
                <table border='1' cellpadding='8' cellspacing='0'>
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

    // Previous 10 records for history
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
                <table border='1' cellpadding='8' cellspacing='0'>
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
        while ($row_hist = pg_fetch_assoc($result_history)) {
            $history_text .= "
                <tr>
                    <td>{$row_hist['rate_date']}</td>
                    <td class='utc-time'
                      data-date=\"{$row_hist['rate_date']}\"
                      data-time=\"{$row_hist['rate_time']}\">
                      {$row_hist['rate_time']}
                   </td>
                    <td>" . format_rate($row_hist['btc_usd']) . "</td>
                    <td>" . format_rate($row_hist['eth_usd']) . "</td>
                    <td>" . format_rate($row_hist['sol_usd']) . "</td>
                </tr>
            ";
        }
        $history_text .= "
                    </tbody>
                </table>
            </div>
        ";
    } else {
        $history_text = "<div class='db-box'><p>No historical records found.</p></div>";
    }

    pg_close($db_conn);
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Welcome to My AWS Website with RDS</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background: #f4f4f4;
      color: #333;
      margin: 0;
      padding: 40px;
      text-align: center;
    }
    .container {
      background: white;
      padding: 30px;
      border-radius: 12px;
      max-width: 700px;
      margin: auto;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
    }
    .db-box {
      background: #eef7ff;
      padding: 20px;
      border-radius: 10px;
      margin-top: 25px;
      font-size: 18px;
      text-align: left;
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
      background: #eef7ff;
    }
    img {
      max-width: 100%;
      border-radius: 8px;
      margin-bottom: 20px;
    }
  </style>
</head>
<body>
  <div class="container">
    <img src="<?= "${cloudfront_url}web_site2/images/crypto.jpg" ?>" alt="Crypto Image" />
    <h1>Welcome to My AWS Website with RDS!</h1>
    <p>This page is running on EC2 → Private RDS PostgreSQL → Terraform-managed infrastructure.</p>

    <div class="db-box">
        <strong>DB Status:</strong> <?= $db_status ?>
    </div>

    <?= $latest_text ?>
    <?= $history_text ?>
  </div>

  <script>
    document.addEventListener("DOMContentLoaded", function () {
        const cells = document.querySelectorAll(".utc-time");

        cells.forEach(cell => {
            const date = cell.getAttribute("data-date");
            const time = cell.getAttribute("data-time").substring(0, 8);

            const utcString = date + "T" + time + "Z"; 
            const localDate = new Date(utcString);

            const localTime = localDate.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit"
            });

            cell.textContent = localTime;
        });
    });
  </script>
</body>
</html>