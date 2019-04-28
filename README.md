# Docker Alpine/PHP/CLI/Composer development image

Pull and run the image :

```shell
$ docker run --rm -it -p 8000:8000 -v $YOUR_PROJECT_ROOT:/srv/web antoine87/dev
```

Once in the shell of the container, start the built-in PHP server yourself or with the default `entrypoint` (by default listens on port `8000` to the `/srv/web/public` directory)

```shell
/srv/web $ entrypoint
PHP 7.3.4 Development Server started at Sun Apr 28 15:50:12 2019
Listening on http://0.0.0.0:8000
Document root is /srv/web/public
Press Ctrl-C to quit.
```

By default `entrypoint` listens on port `8000` to the `/srv/web/public` directory.
 
