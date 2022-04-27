# Avoidance
## A void dance.

A void post installation program that installs and configures packages and makes it usable with ease.
The idea behind this project is to create a simple shell program that people can run from tty as a part of the post installation process and get a complete usable distribution.

This is an ongoing process as there can be many additional features added , such as configuring behaviors and appears of applications, adding more software choices, and providing choice of set of application geared towards specific purpose like programming, sys admin, design, gaming, desktop use etc. Any kind of contributions are welcome, please check contributing guidelines below for details.

### It installs:
- All required basic utilities such as X Server, Audio server etc.
- A desktop or window manager of choice, currently supported:
    - Gnome
    - KDE Plasma
    - BSPWM
- Polybar if the Window Manager is BSPWM
- Terminals, such as:
    - st
    - urxvt
    - Konsole (with KDE)
    - Gnome Terminal (with Gnome)
- A text editor of choice:
    - Emacs
    - VIM
    - Gedit
    - Kate
    - Nano
    - VS Code
- All Gnome basic applications if the Gnome Desktop is choses, and all KDE basic applications if KDE Plasma desktop is chosen.

### It automatically configures
- Wifi, if selected.
- Touchpad.
- Sound.
- Window manager, if selected.

### Installation instructions
+ First, follow the installation guide from the Void's official installation guide pages at:
`https://docs.voidlinux.org/installation/live-images/guide.html`

+ After you have installed the bare minimum Void system and rebooted your machine, run update as prescribed by typing:
IMPORTANT: FOR ALL THE PROCEDURES BELLOW, DO NOT COPY SIGNS # OR $

``` bash
# xbps-install -Su
```
You may need super user previleges for this, in such case do:

``` bash
# sudo xbps-install -Su
```

+ Install and configure git, and optionally rsync:

``` bash
# sudo xbps-install Suy git rsync && git config --global user.name "Temp User" && git config --global user.email temp_user@not.provided
```
We set git user as Temp User and email as temp_user@not.provided for now. Do not worry, you can change this anytime later.

+ Clone this repository and start the program (run line by line):

``` bash
$ git clone https://github.com/DaxGoon/avoidance.git
$ cd avoidance
$ find . -name "*.sh" -exec chmod +x {} \;
$ ./avoidance-start.sh
```
Now the installation process will start, just follow along to set your choices.

### Contributing Guidelines
Any contribution is requested and appreciated. All contribution is either a new feature, a new fix or a new change and before you begin working on a contribution please create an issue requesting that and mention that you would like to work on that. This will help us not do the same things by multiple people. Also, please check if there is an existing issue and see if somebody else is working on your idea.

After that:
- Clone this repository,
- Work on your contribution idea,
- Test locally if it works,
- And make a pull request.

Please make sure:
- There is only one commit per feature/fix/change
- Start your commit by indicating the type as:
    - feat: <commit msg>
    - fix: <commit msg>
    - change: <commit msg>

    for example,
    ```
    feat: Add new desktop choices.
    change: move all util functions to their own files.
    fix: fix error on some_func fiunction for ...
    ```
Let's make this happen.
