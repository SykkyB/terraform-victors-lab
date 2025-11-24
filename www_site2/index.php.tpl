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
    $db_status = "❌ Failed to connect to Postgres DB: " . pg_last_error();
    $latest_text = "";
} else {
    $db_status = "✅ Postgres DB connected successfully.";

    // ---------------------------
    // Fetch Latest Crypto Rates
    // ---------------------------
    $query = "
        SELECT *
        FROM public.crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        LIMIT 1;
    ";

    $result = pg_query($db_conn, $query);

    if (!$result) {
        $latest_text = "Query failed: " . pg_last_error();
    } elseif (pg_num_rows($result) == 0) {
        $latest_text = "No crypto rates found.";
    } else {
        $row = pg_fetch_assoc($result);
        $latest_text = "
            <div class='db-box'>
                <h2>Latest Crypto Rates</h2>
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
            </div>
        ";
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
  </div>
</body>
</html>
