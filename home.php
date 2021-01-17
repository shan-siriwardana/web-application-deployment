<!DOCTYPE html>
<html>
<body>

<h1 style="color:blue;text-align:center">Hello World</h1>

<h2>file uploaders</h2>
<?php

$dir    = '/mys3bucket';
$files = array_diff(scandir($dir),array('..', '.'));


foreach($files as $file){
        $filepath = $dir."/".$file;
        echo readfile($filepath);
        echo  nl2br ("\n");
}
echo  nl2br ("\n");

?>

</body>
</html>
