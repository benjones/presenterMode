# Presenter Mode

Presenter mode is a Mac App for mirroring a window or ipad into another window.

Watch [this quick overview video](https://youtu.be/sBFA_YjKue8) to get an idea of how it works and how you might want to use it.  

Why would you do this?

This has been super useful to me as a professor when I want to live code or show something in a terminal in class, but want to keep some notes open for myself.  

Before Presenter Mode, I could either mirror my laptop display, which means my notes are visible to my students as well me, or I could extend my display to the projector, and try to contort my head to look at the projector while keeping my laptop screen private. 

With Presenter Mode, I extend my desktop to the projector and maxmize the Presenter Mode mirror window onto it.  Then I can share any window I want to the projector and quickly switch between slides, code, terminal, or my iPad screen.  

I can also share my mirror window over Zoom so remote students see the same things that in-person students do, and only the window I want is recorded.

Now, in version 3, PresenterMode can record a video of the mirror window voiceover.  Using my mac's built in mic works pretty well, but wired external mics also seem to work fine.  The video files may be relatively large, so you may want to compress them after you're done with your lecture.

## User Manual

The UI is pretty basic.  When you open it, it will open the "picker window" and trigger Macos's screen sharing picker widget in the menu bar.  **Note, Apple has changed the UI of the sharing picker in MacOS 15, so it will look different!**

From the screen sharing widget, you can select a window, app, or display to share.  When you select a window, it will open Presenter Mode's mirror window which will show the live content from the window you're sharing.  You can switch between windows/apps/displays using the menubar widget.

The picker window will show windows you've shared recently so you can quickly switch to something you've shared.  It will also display any AV devices that can be shared, usually your webcam, or an Ipad if you have one connected.

When you run it the first time, you'll probably have to OK to run code that's downloaded from the internet.  You can do this by going to system settings -> Privacy and Security.  It should show the presenter mode icon and an "open anyway" button.  

Presenter Mode will request some permissions (for screen recording, and camera which is needed for ipad mirroring).  Since version 3, the app will request microphone and file storage permissions for saving the recordings to video files.  You may also need to set your ipad up to trust your laptop.

## Known Bugs

* If you enable horizontal flipping of the content, then resize the mirror window, the content gets un-flipped and you have to reselect horizontal mirroring
* Video recording seems to be reliable, but my pixel buds mic produces horrible sounds.  Built in mic, and wired external mics seem to work. 
* Not super important given :points up: but you can't switch the audio device while you're recording (yet)
* Video recording doesn't mirror the shared content, even though the window does (yet)

## Contact

Feel free to use Github Issues for bug reports or feature requests, and/or contact me via email.  My name is Ben Jones and I teach in the University of Utah School of Computing.
