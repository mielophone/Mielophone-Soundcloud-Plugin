package
{
	import com.codezen.helper.WebWorker;
	import com.codezen.music.playr.Playr;
	import com.codezen.music.playr.PlayrTrack;
	import com.codezen.music.search.ISearchProvider;
	import com.dasflash.soundcloud.as3api.SoundcloudClient;
	import com.dasflash.soundcloud.as3api.SoundcloudDelegate;
	import com.dasflash.soundcloud.as3api.events.SoundcloudAuthEvent;
	import com.dasflash.soundcloud.as3api.events.SoundcloudEvent;
	import com.dasflash.soundcloud.as3api.events.SoundcloudFaultEvent;
	
	import flash.display.Sprite;
	import flash.net.URLRequestMethod;
	
	public class Searcher extends WebWorker implements ISearchProvider
	{
		// results array
		private var _result:Vector.<PlayrTrack>;
		
		// sound cloud stuff
		private var sc:SoundcloudClient;
		private var delegate:SoundcloudDelegate;
		private static var scConsumerKey:String = "IFDZYoK6v6J27zvX4MxcA";
		private static var scConsumerSecret:String = "AC5r8JItkWptnnZ6cUeiqIQnkY93GsuRWBlrAeSt8";
		
		public function Searcher()
		{
			super();
			initSoundcloud();
		}
		
		public function get PLUGIN_NAME():String{
			return "Soundcloud MP3 Search";
		}
		
		public function get AUTHOR_NAME():String{
			return "yamalight";
		}
		
		public function get result():Vector.<PlayrTrack>{
			return _result;
		}
		
		private function initSoundcloud():void{
			trace('initing soundcloud');
			// init soundcloud api
			sc = new SoundcloudClient(scConsumerKey, scConsumerSecret, null, false);
			sc.addEventListener(SoundcloudAuthEvent.REQUEST_TOKEN, requestTokenHandler);
			sc.getRequestToken();
		}
		
		private function requestTokenHandler(event:SoundcloudAuthEvent):void{
			trace("request token received: "+event.token.key+", "+event.token.secret);
		}
		
		public function search(query:String, durationMs:int = 0):void{			
			var params:Object = {};
			params.filter = "streamable,downloadable";
			if( durationMs > 0 ){
				params["duration[from]"] = durationMs - 1000;
				params["duration[to]"] = durationMs + 1000;
			}
			params.q = query;
			
			trace('doing single request: '+query);
			//trace(ObjectUtil.toString(params));
			delegate = sc.sendRequest("tracks", URLRequestMethod.GET, params); 
			delegate.addEventListener(SoundcloudEvent.REQUEST_COMPLETE, onSingleSongData);
			delegate.addEventListener(SoundcloudFaultEvent.FAULT, onSingleSongFault);
			delegate.execute();
		}
		
		private function onSingleSongData(e:SoundcloudEvent):void{
			delegate.removeEventListener(SoundcloudEvent.REQUEST_COMPLETE, onSingleSongData);
			
			var xml:XML = new XML(e.data);
			var tracks:XMLList = xml.children();
			
			if(tracks.length() < 1){
				dispatchError("Nothing found");
				return;
			}
			
			_result = new Vector.<PlayrTrack>();
			
			var item:XML;
			var obj:PlayrTrack;
			
			var sec:int;
			var min:int;
			var time:String;
			
			for each(item in tracks){
				if(item.downloadable.text() == false){ trace('false!'); continue; }
				
				sec = int( item.duration.text() / 1000 );
				min = sec/60;
				sec -= min*60;
				time = min+":";
				if( sec < 10 ){
					time += "0"+sec;
				}else{
					time += sec;
				}
				
				trace(item);
				
				obj = new PlayrTrack();
				obj.title = item.title.text();
				obj.downloadRequest = sc.getSignedURLRequest(item["download-url"].text());//item["stream-url"].text();
				obj.streamRequest = sc.getSignedURLRequest(item["stream-url"].text());
				obj.totalSeconds = int( item.duration.text() / 1000 );
				obj.totalTime = time;
				
				_result.push(obj);
			}
			
			endLoad();
		}
		
		private function onSingleSongFault(e:SoundcloudFaultEvent):void{ 
			dispatchError("Nothing found");
		}
	}
}