# 17-Aug-2025
* Integrated Assemblyai to generate the chapters.

### How it works?
* User provides the video id.
* Agent accepts the request and provides the user with a request id. And then it creates a background job to do further processing in it.
* Agent sends a request to the python app to extract the audio from the youtube video.
* Python app provides the path where the audio file exists in the filesystem
* Agent sends a request to Assemblyai with the downloaded audio to generate chapters.
* Agent exposes an api to fetch the status of the request based on the request id provided.
