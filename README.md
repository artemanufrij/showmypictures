<div>
  <h1 align="center">Show My Pictures</h1>
  <h3 align="center">An image viewer for manage local image files</h3>
  <p align="center">Designed for <a href="https://elementary.io"> elementary OS</p>
</div>
<p align="center">
  <a href="https://appcenter.elementary.io/com.github.artemanufrij.showmypictures">
    <img src="https://appcenter.elementary.io/badge.svg" alt="Get it on AppCenter">
  </a>
</p>

<br/>

![screenshot](Screenshot.png)

## Donations
If you liked _Show My Pictures_, and would like to support it's development of this app and more, consider [buying me a coffee](https://www.paypal.me/ArtemAnufrij) :) 

## Install from Github.

As first you need elementary SDK
```
sudo apt install elementary-sdk
```

Install dependencies
```
sudo apt install libsqlite3-dev
sudo apt install libexif-dev
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

Install and start Show My Pictures on your system
```
sudo make install
com.github.artemanufrij.showmypictures
```
