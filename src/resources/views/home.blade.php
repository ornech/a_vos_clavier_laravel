<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Aux claviers citoyens !</title>
    <style>
        html, body { height: 100%; margin: 0; }
        body {
            display: flex;
            align-items: center;
            justify-content: center;
            background: #fff;
        }
        img { max-width: 90vw; max-height: 94vh; height: auto; width: auto; }
    </style>
</head>
<body>
    <img src="{{ asset('images/aux-claviers-citoyens.png') }}"
         alt="Logo « Aux claviers citoyens ! » : une Marianne casquée, en armure, tient un drapeau aux chiffres binaires bleu, blanc, rouge"
         width="352" height="704">
</body>
</html>
