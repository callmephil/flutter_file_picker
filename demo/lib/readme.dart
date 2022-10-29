/* Lifecycle */
// ? if client is disposed (page change, picking different file). cancel the request and destroy the instance.
// ? We should not cancel upload if the client is not active. (switching app, tabs)
// ! Must implement .dispose() method.

/* PRE UPLOAD PROCCESS (INIT) */
// * Get the upload id.
// ! Must implement .getUploadID() method.
// ? if it fail. attempt retry,
// ? if it fails again, notify the client for manual init restart.
// ! Must implement .restart() method.
// ? if it succeeds, initalise _streamSubscription and continue.
// ! Must initialise a new cancelation token for every requests.

/* START UPLOAD PROCCESS */
// * Listen to _streamSubscription
// * Notify the client that we are starting the upload.
// * Pause the stream
// ? if the stream fail, we must cancel the process and notify the client for re-picking.
// * Manage the chunk.

// Should be called manageResponse*
/* MANAGE CHUNK PROCCESS */
// * listen for connection changes.
// ! Must implement ConnectionStatusSingleton
// ? if the connection is offline, retry _manageChunk() after 5 seconds.
// ? if failure -> notify client with _isPendingRestart = true (the stream is already paused).
// ? Storing the chunk in the instance so we can resume it later. if needed
// ! Note: We should not pause the stream a second time. if we do so, we will need to resume it a second time.
// ! Must implement .resume() method.
// * Send the chunk to the server and wait for response.
// ! Must implement .sendChunk() method.
// ? if errors occurs retry to send the chunk.
// ? if errors occurs again, notify the client for manual restart.
// ? if success. update chunkID & startingRange and resume the stream.

/* SEND CHUNK PROCESS */
// * initialise dio PUT request.
// * send the chunk as a stream.
// * manage progress.
// ? We have 2 type of progress.
// ? 1. Chunk progress (the upload progress of the current chunk).
// ! Must implement .manageUploadProgress() Method.
// ? 2. Stream progress (the upload progress of the whole stream).
// ! Must implement .manageStreamProgress() Method.
// * manage the cancelation token.
// ! Must initialise a new cancelation token for every requests.
// ? If cancel is called, cancel the request and notify the client for manual restart.
// ? If the client destroy the u.i manually dispose. (ex: delete the file, change page, etc.)
// * Manage response.
// ? We must ensure the function is

/* MANUAL RESUME PROCCESS */
// ? we must expose a manual resume method.
// ? we must expose a resume listener. variable isManualResumed.
// ? We must set _isManualPaused = false
// * if we resume and we have canceled the request
// * if the chunk has finished then we should resume the listener
// * otherwise we must restart the upload from the last chunk before running the stream.

/* MANUAL PAUSE PROCCESS */
// ! Must implement .pause() method.
// ? we must expose a pause listener. variable isManualPaused.
// ? we need to decide if we should cancel the upload or wait till he has finished the chunk.
// ! note: the above can be avoided if we have smaller chunks. ~ 5 - 10mb. for carrier data.
// ? On manual pause we set _isManualPaused = true, and we pause the stream.

/* RESTART PROCCESS */
// * if isPendingRestart -> must call _manualRestart -> manageChunk -> resume on success. <|> do nothing on failure.
// ? When manual restart we send a single manageChunk and if success we resume the stream.
// ? We repeat the whole process again until done or cancel or destroy.

/* CANCEL PROCCESS */
// ! Must expose a manual cancel method.
// ? Must have a confirmation dialog before canceling.
// * On cancel we call cancelToken & subscription.cancel()
// * notify the client that the upload has been canceled.

/* PENDING RESTART PROCCESS */
// ! Must implement .restart() method.
// ? if the client restart the process. we must know if upload id is available or not.
// ? if upload id is available, we call the .resume() method
// ? if cancel -> notify client with _isCanceled -> clear the instance. (destroy on u.i change).
