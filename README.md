<div>
  <h1 align="center">Memories</h1>
  <h3 align="center"><img src="data/icons/com.github.artemanufrij.showmypictures.svg"/><br>An image viewer for managing local image files</h3>
  <p align="center">Designed for <a href="https://elementary.io"> elementary OS</p>
</div>

### Donate
<a href="https://www.paypal.me/ArtemAnufrij">PayPal</a> | <a href="https://liberapay.com/Artem/donate">LiberaPay</a> | <a href="https://www.patreon.com/ArtemAnufrij">Patreon</a>

<p align="center">
  <a href="https://appcenter.elementary.io/com.github.artemanufrij.showmypictures">
    <img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter">
  </a>
  <p align="center">
    <img src="screenshots/Screenshot.png"/>
    <img src="screenshots/Screenshot_Album.png"/>
    <img src="screenshots/Screenshot_Picture.png"/>
  </p>
</p>

## Install from Github.

As first you need elementary SDK
```
sudo apt install elementary-sdk
```

Install dependencies
```
sudo apt install libsqlite3-dev libgexiv2-dev libraw-dev webkit2gtk-4.0
```

Clone repository and change directory
```
git clone https://github.com/artemanufrij/showmypictures.git
cd showmypictures
```

Create **build** folder, compile and start application
```
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make
```

Install and start _Show My Pictures_ on your system
```
sudo make install
com.github.artemanufrij.showmypictures
```
