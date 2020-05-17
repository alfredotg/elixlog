<?php

$curl = curl_init();
//curl_setopt($curl, CURLOPT_VERBOSE, 1);
curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);

$api = function(bool $post, string $path, array $data) use($curl) {
    if(!$post)
      $path .= '?' . http_build_query($data);
    curl_setopt($curl, CURLOPT_URL, 'http://localhost:4000'.$path);
    curl_setopt($curl, CURLOPT_POST, $post);
    if($post)
      curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($curl, CURLOPT_HTTPHEADER, array('Content-type: application/json'));
    return curl_exec($curl);
};

$res = $api(true, '/visited_links', ['link' => ['ya.ru', 'http://frobes.frob']]);
printf("Bad request %s\n", $res);

$res = $api(true, '/visited_links', ['links' => ['ya.ru', 'http://frobes.frob']]);
printf("Save response %s\n", $res);

$res = $api(false, '/visited_domains', ['from' => time() - 10, 'to' => time()]);
printf("Fetch response %s\n", $res);
