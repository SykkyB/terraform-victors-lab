<?php
// ---------------------------
// DB connection
// ---------------------------
$db_host = "${db_host}";
$db_name = "${db_name}";
$db_user = "${db_user}";
$db_pass = "${db_pass}";
$db_port = "5432";

$conn = pg_connect("host=$db_host port=$db_port dbname=$db_name user=$db_user password=$db_pass");
date_default_timezone_set('Asia/Tbilisi');

// ---------------------------
// helpers
// ---------------------------
function fmt($v) {
    return rtrim(rtrim(number_format((float)$v, 8, '.', ''), '0'), '.');
}

function delta($curr, $prev) {
    if ($prev == 0 || $prev === null) return ["", "", "neutral"];
    $diff = $curr - $prev;
    $pct  = ($diff / $prev) * 100;

    if ($diff > 0) return ["▲", sprintf("+%.2f%%", $pct), "up"];
    if ($diff < 0) return ["▼", sprintf("%.2f%%", $pct), "down"];
    return ["", "0.00%", "neutral"];
}

// ---------------------------
// data
// ---------------------------
$latest = null;
$prev   = null;
$history = [];
$chart   = [];

if ($conn) {
    // latest + previous
    $r = pg_query($conn,"
        SELECT * FROM crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        LIMIT 2
    ");
    if (pg_num_rows($r) >= 1) {
        $latest = pg_fetch_assoc($r);
        $prev   = pg_fetch_assoc($r);
    }

    // history
    $h = pg_query($conn,"
        SELECT * FROM crypto_rates
        ORDER BY rate_date DESC, rate_time DESC
        OFFSET 1 LIMIT 10
    ");
    while ($row = pg_fetch_assoc($h)) {
        $history[] = $row;
    }

    // chart 24h
    $c = pg_query($conn,"
        SELECT rate_date, rate_time, btc_usd, eth_usd, sol_usd
        FROM crypto_rates
        WHERE (rate_date + rate_time) >= NOW() - INTERVAL '1 day'
        ORDER BY rate_date, rate_time
    ");
    while ($r = pg_fetch_assoc($c)) {
        $dt = new DateTime(
            $r['rate_date'].' '.substr($r['rate_time'],0,8),
            new DateTimeZone("UTC")
        );
        $dt->setTimezone(new DateTimeZone("Asia/Tbilisi"));
        $chart[] = [
            "t"   => $dt->format("H:i"),
            "btc" => (float)$r['btc_usd'],
            "eth" => (float)$r['eth_usd'],
            "sol" => (float)$r['sol_usd']
        ];
    }

    pg_close($conn);
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Crypto Dashboard</title>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

<style>
body { margin:0; font-family:Arial,sans-serif; background:#f4f4f4; }
.container { max-width:900px; margin:auto; padding:16px; background:#fff; }

.db-box {
    background:#eef7ff;
    border-radius:10px;
    padding:16px;
    margin-top:20px;
}

.table-wrap { overflow-x:auto; }
table { width:100%; border-collapse:collapse; min-width:520px; }
th,td { padding:8px; border:1px solid #ccc; text-align:center; }

.card {
    background:#fff;
    border-radius:10px;
    padding:12px;
    margin-bottom:12px;
    box-shadow:0 2px 6px rgba(0,0,0,.1);
}
.card-time { font-size:12px; color:#666; margin-bottom:6px; }

.up { color:#1aa34a; font-weight:bold; }
.down { color:#d93025; font-weight:bold; }
.neutral { color:#666; }

.chart-wrap { position:relative; height:320px; }
.controls { text-align:center; margin-bottom:10px; }
.controls button {
    padding:6px 12px;
    margin:0 4px;
    border-radius:6px;
    border:1px solid #999;
    background:#fff;
}
.controls button.active { background:#007bff; color:#fff; }

.latest-card, .history-cards { display:none; }

@media(max-width:768px){
    table { display:none; }
    .latest-card, .history-cards { display:block; }
    .chart-wrap { height:220px; }
}
</style>
</head>

<body>
<div class="container">

<img src="<?= "${cloudfront_url}web_site2/images/crypto.jpg" ?>"
     style="width:100%;border-radius:10px">

<h1>Crypto Rates Dashboard</h1>

<?php if ($latest): ?>
<?php
[$btc_a,$btc_p,$btc_c] = delta($latest['btc_usd'],$prev['btc_usd']);
[$eth_a,$eth_p,$eth_c] = delta($latest['eth_usd'],$prev['eth_usd']);
[$sol_a,$sol_p,$sol_c] = delta($latest['sol_usd'],$prev['sol_usd']);
?>

<!-- Latest -->
<div class="db-box">
<h2>Latest</h2>

<div class="table-wrap">
<table>
<tr><th>Asset</th><th>Value</th><th>Change</th></tr>
<tr><td>BTC</td><td><?= fmt($latest['btc_usd']) ?></td><td class="<?= $btc_c ?>"><?= $btc_a ?> <?= $btc_p ?></td></tr>
<tr><td>ETH</td><td><?= fmt($latest['eth_usd']) ?></td><td class="<?= $eth_c ?>"><?= $eth_a ?> <?= $eth_p ?></td></tr>
<tr><td>SOL</td><td><?= fmt($latest['sol_usd']) ?></td><td class="<?= $sol_c ?>"><?= $sol_a ?> <?= $sol_p ?></td></tr>
</table>
</div>

<div class="latest-card">
<div class="card">
<div class="card-time"><?= $latest['rate_date'] ?> <?= substr($latest['rate_time'],0,8) ?></div>
<div class="<?= $btc_c ?>">BTC: <?= fmt($latest['btc_usd']) ?> <?= $btc_a ?> <?= $btc_p ?></div>
<div class="<?= $eth_c ?>">ETH: <?= fmt($latest['eth_usd']) ?> <?= $eth_a ?> <?= $eth_p ?></div>
<div class="<?= $sol_c ?>">SOL: <?= fmt($latest['sol_usd']) ?> <?= $sol_a ?> <?= $sol_p ?></div>
</div>
</div>

</div>
<?php endif; ?>

<!-- Chart -->
<div class="db-box">
<h2>Chart</h2>

<div class="controls">
<button data-h="1" class="active">1h</button>
<button data-h="8">8h</button>
<button data-h="24">1d</button>
</div>

<div class="chart-wrap">
<canvas id="cryptoChart"></canvas>
</div>
</div>

<!-- History -->
<div class="db-box">
<h2>History</h2>

<div class="table-wrap">
<table>
<tr><th>Time</th><th>BTC</th><th>ETH</th><th>SOL</th></tr>
<?php
$prevRow = $latest;
foreach ($history as $r):
    [$b_a,$b_p,$b_c] = delta($r['btc_usd'],$prevRow['btc_usd']);
    [$e_a,$e_p,$e_c] = delta($r['eth_usd'],$prevRow['eth_usd']);
    [$s_a,$s_p,$s_c] = delta($r['sol_usd'],$prevRow['sol_usd']);
?>
<tr>
<td><?= $r['rate_date'] ?> <?= substr($r['rate_time'],0,8) ?></td>
<td class="<?= $b_c ?>"><?= fmt($r['btc_usd']) ?> <?= $b_a ?></td>
<td class="<?= $e_c ?>"><?= fmt($r['eth_usd']) ?> <?= $e_a ?></td>
<td class="<?= $s_c ?>"><?= fmt($r['sol_usd']) ?> <?= $s_a ?></td>
</tr>
<?php $prevRow=$r; endforeach; ?>
</table>
</div>

<div class="history-cards">
<?php
$prevRow = $latest;
$mobileCount = 0;

foreach ($history as $r):
    if ($mobileCount >= 2) break;
    [$b_a,$b_p,$b_c] = delta($r['btc_usd'],$prevRow['btc_usd']);
    [$e_a,$e_p,$e_c] = delta($r['eth_usd'],$prevRow['eth_usd']);
    [$s_a,$s_p,$s_c] = delta($r['sol_usd'],$prevRow['sol_usd']);
?>
<div class="card">
<div class="card-time"><?= $r['rate_date'] ?> <?= substr($r['rate_time'],0,8) ?></div>
<div class="<?= $b_c ?>">BTC: <?= fmt($r['btc_usd']) ?> <?= $b_a ?> <?= $b_p ?></div>
<div class="<?= $e_c ?>">ETH: <?= fmt($r['eth_usd']) ?> <?= $e_a ?> <?= $e_p ?></div>
<div class="<?= $s_c ?>">SOL: <?= fmt($r['sol_usd']) ?> <?= $s_a ?> <?= $s_p ?></div>
</div>
<?php
    $prevRow = $r;
    $mobileCount++;
endforeach;
?>
</div>

</div>

</div>

<script>
const raw = <?= json_encode($chart) ?>;
let chart, current = 0;

function slice(hours){
    return raw.slice(-(hours*12)); // 5min intervals
}

function build(data){
    const ctx = document.getElementById("cryptoChart");
    chart = new Chart(ctx,{
        type:"line",
        data:{
            labels:data.map(p=>p.t),
            datasets:[
                {label:"BTC",data:data.map(p=>p.btc),yAxisID:"yBtc",borderColor:"#f7931a"},
                {label:"ETH",data:data.map(p=>p.eth),yAxisID:"yAlt",borderColor:"#3c3c3d",hidden:true},
                {label:"SOL",data:data.map(p=>p.sol),yAxisID:"yAlt",borderColor:"#00ffa3",hidden:true}
            ]
        },
        options:{
            responsive:true,
            maintainAspectRatio:false,
            interaction:{mode:"index",intersect:false},
            scales:{
                yBtc:{position:"left"},
                yAlt:{position:"right",grid:{drawOnChartArea:false}}
            }
        }
    });

    let startX=0;
    ctx.addEventListener("touchstart",e=>startX=e.touches[0].clientX);
    ctx.addEventListener("touchend",e=>{
        let d=e.changedTouches[0].clientX-startX;
        if(Math.abs(d)>40){
            current=(d<0)?(current+1)%3:(current+2)%3;
            chart.data.datasets.forEach((ds,i)=>ds.hidden=i!==current);
            chart.update();
        }
    });
}

// lazy load
const obs = new IntersectionObserver(e=>{
    if(e[0].isIntersecting){
        build(slice(1));
        obs.disconnect();
    }
});
obs.observe(document.querySelector(".chart-wrap"));

// period buttons
document.querySelectorAll(".controls button").forEach(b=>{
    b.onclick=()=>{
        document.querySelectorAll(".controls button").forEach(x=>x.classList.remove("active"));
        b.classList.add("active");
        chart.destroy();
        build(slice(b.dataset.h));
    };
});
</script>

</body>
</html>
