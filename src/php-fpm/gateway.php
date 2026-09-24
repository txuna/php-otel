<?php 

require 'vendor/autoload.php';

class DemoClass
{
    public function run(): void
    {
        echo "Hello Tuuna\n";
    }
}

$demo = new DemoClass();
$demo->run();