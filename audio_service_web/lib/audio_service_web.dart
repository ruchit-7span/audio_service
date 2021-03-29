import 'dart:async';
import 'dart:html' as html;

import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:js' as js;
import 'js/media_session_web.dart';

class AudioServiceWeb extends AudioServicePlatform {
  static void registerWith(Registrar registrar) {
    AudioServicePlatform.instance = AudioServiceWeb();
  }

  AudioHandlerCallbacks? handlerCallbacks;
  MediaItem? mediaItem;

  @override
  Future<ConfigureResponse> configure(ConfigureRequest request) async {
    return ConfigureResponse();
    // throw UnimplementedError('configure() has not been implemented.');
  }

  Future<void> setState(SetStateRequest request) async {
    print('Setting state');
    final session = html.window.navigator.mediaSession!;
    for (final control in request.state.controls) {
      try {
        switch (control.action) {
          case MediaActionMessage.play:
            session.setActionHandler(
              'play',
              () => handlerCallbacks?.play(PlayRequest()),
            );
            break;
          case MediaActionMessage.pause:
            session.setActionHandler(
              'pause',
              () => handlerCallbacks?.pause(PauseRequest()),
            );
            break;
          case MediaActionMessage.skipToPrevious:
            session.setActionHandler(
              'previoustrack',
              () => handlerCallbacks?.skipToPrevious(SkipToPreviousRequest()),
            );
            break;
          case MediaActionMessage.skipToNext:
            session.setActionHandler(
              'nexttrack',
              () => handlerCallbacks?.skipToNext(SkipToNextRequest()),
            );
            break;
          // The naming convention here is a bit odd but seekbackward seems more
          // analagous to rewind than seekBackward
          case MediaActionMessage.rewind:
            session.setActionHandler(
              'seekbackward',
              () => handlerCallbacks?.rewind(RewindRequest()),
            );
            break;
          case MediaActionMessage.fastForward:
            session.setActionHandler(
              'seekforward',
              () => handlerCallbacks?.fastForward(FastForwardRequest()),
            );
            break;
          case MediaActionMessage.stop:
            session.setActionHandler(
              'stop',
              () => handlerCallbacks?.stop(StopRequest()),
            );
            break;
          default:
            // no-op
            break;
        }
      } catch (e) {}
      for (MediaActionMessage message in request.state.systemActions) {
        switch (message) {
          case MediaActionMessage.seek:
            try {
              setActionHandler('seekto', js.allowInterop((ActionResult ev) {
                // Chrome uses seconds for whatever reason
                handlerCallbacks?.seek(SeekRequest(
                    position: Duration(
                  milliseconds: (ev.seekTime * 1000).round(),
                )));
              }));
            } catch (e) {}
            break;
          default:
            // no-op
            break;
        }
      }

      try {
        // Dart also doesn't expose setPositionState
        if (mediaItem != null) {
          //print(
          //    'Setting positionState Duration(${mediaItem!.duration?.inSeconds}), PlaybackRate(${args[6] ?? 1.0}), Position(${Duration(milliseconds: args[4])?.inSeconds})');

          // Chrome looks for seconds for some reason
          setPositionState(PositionState(
            duration: (mediaItem!.duration?.inMilliseconds ?? 0) / 1000,
            playbackRate: request.state.speed,
            position: request.state.updatePosition.inMilliseconds / 1000,
          ));
        }
      } catch (e) {
        print(e);
      }
    }
  }

  Future<void> setQueue(SetQueueRequest request) async {
    //no-op there is not a queue concept on the web
  }

  Future<void> setMediaItem(SetMediaItemRequest request) async {
    final mediaItem = request.mediaItem;
    final artUri = mediaItem.artUri;

    print('setting media item!');

    try {
      metadata = html.MediaMetadata({
        'album': mediaItem.album,
        'title': mediaItem.title,
        'artist': mediaItem.artist,
        'artwork': [
          {
            'src': artUri,
            'sizes': '512x512',
          }
        ],
      });
    } catch (e) {
      print('Metadata failed $e');
    }
  }

  Future<void> stopService(StopServiceRequest request) async {
    final session = html.window.navigator.mediaSession!;
    session.metadata = null;
    mediaItem = null;

    // Not sure if anything needs to happen here
    // throw UnimplementedError('stopService() has not been implemented.');
  }

  void setClientCallbacks(AudioClientCallbacks callbacks) {}

  void setHandlerCallbacks(AudioHandlerCallbacks callbacks) {
    // Save this here so that we can modify which handlers are set based
    // on which actions are enabled
    handlerCallbacks = callbacks;
  }
}
