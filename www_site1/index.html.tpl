<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Welcome to My AWS Static Website</title>

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
      max-width: 600px;
      margin: auto;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
    }

    img {
      max-width: 100%;
      border-radius: 8px;
      margin-top: 20px;
    }
  </style>
</head>
<body>

  <div class="container">
    <h1>Welcome to My AWS Static Website!</h1>
    <p>This page is deployed using Terraform → S3 → CloudFront.</p>

    <img src="${cloudfront_url}web_site1/images/test_site_image.jpg" alt="Test Image" />
  </div>

</body>
</html>