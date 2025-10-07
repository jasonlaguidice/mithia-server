<?php
/* Minimal phpMyAdmin config for Docker compose stack */
$cfg['blowfish_secret'] = 'change-this-to-a-32+char-random-secret-9f6e2c4b0f1a7d3c5e8b2a4c6d7e9f0a';

$i = 0;
$i++;
$cfg['Servers'][$i]['auth_type'] = 'cookie';
$cfg['Servers'][$i]['host'] = 'mithia-db';
$cfg['Servers'][$i]['port'] = '3306';
$cfg['Servers'][$i]['compress'] = false;
$cfg['Servers'][$i]['AllowNoPassword'] = false;

$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['TempDir'] = __DIR__ . '/tmp';
