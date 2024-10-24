//
//  TODO.md
//  presenterMode
//
//  Created by Ben Jones on 10/22/24.
//

* Handle switching audio inputs while recording
	* Probably requires unconditionally creating and audio track and writing silence to it unless there's an audio device?  Probably not worth the effort?
* Do mirroring in video
* Previews for UI components
* Store filters in history, rather than just windows?

## Manual testing operations

Should be done before major releases

* Switching between windows chosen by picker, shared AV devices, history options
* Closing windows which appear in the history menu
* recording video
	* stopping manually
	* quitting the app to stop recording
* Probably buggy:
	* Close the mirror window while recording
	* switching audio devices while debugging



