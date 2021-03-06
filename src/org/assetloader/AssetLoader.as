package org.assetloader
{
	import flash.events.AsyncErrorEvent;

	import org.assetloader.base.AssetLoaderBase;
	import org.assetloader.base.AssetParam;
	import org.assetloader.core.IAssetLoader;
	import org.assetloader.core.ILoadUnit;
	import org.assetloader.core.ILoader;
	import org.assetloader.events.AssetLoaderEvent;

	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;

	[Event(name="ASSET_LOADED", type="org.assetloader.events.AssetLoaderEvent")]

	[Event(name="COMPLETE", type="org.assetloader.events.AssetLoaderEvent")]

	[Event(name="PROGRESS", type="org.assetloader.events.AssetLoaderEvent")]

	[Event(name="ERROR", type="org.assetloader.events.AssetLoaderEvent")]

	[Event(name="BINARY_LOADED", type="org.assetloader.events.BinaryAssetEvent")]
	[Event(name="CSS_LOADED", type="org.assetloader.events.CSSAssetEvent")]
	[Event(name="DISPLAY_OBJECT_LOADED", type="org.assetloader.events.DisplayObjectAssetEvent")]
	[Event(name="IMAGE_LOADED", type="org.assetloader.events.ImageAssetEvent")]
	[Event(name="JSON_LOADED", type="org.assetloader.events.JSONAssetEvent")]
	[Event(name="SOUND_LOADED", type="org.assetloader.events.SoundAssetEvent")]
	[Event(name="SWF_LOADED", type="org.assetloader.events.SWFAssetEvent")]
	[Event(name="TEXT_LOADED", type="org.assetloader.events.TextAssetEvent")]
	[Event(name="VIDEO_LOADED", type="org.assetloader.events.VideoAssetEvent")]
	[Event(name="XML_LOADED", type="org.assetloader.events.XMLAssetEvent")]

	/**
	 * @author Matan Uberstein
	 */
	public class AssetLoader extends AssetLoaderBase implements IAssetLoader
	{
		protected var _numLoaded : int;
		protected var _totalUnits : int;

		protected var _progress : Number;
		protected var _bytesLoaded : uint;
		protected var _bytesTotal : uint;

		[Inject]

		public function AssetLoader(eventDispatcher : IEventDispatcher = null)
		{
			super(eventDispatcher);
		}

		public function start(numConnections : uint = 3) : void
		{
			if(numConnections <= 0)
				throw new ArgumentError("numConnections must be greater that 0");
				
			_numLoaded = 0;
			_totalUnits = _ids.length;
			
			for(var i : int = 0;i < _totalUnits;i++) 
			{
				var unit : ILoadUnit = _units[_ids[i]];
				var loader : ILoader = unit.loader;
				
				if(loader.loaded)
					_numLoaded++;
			}
			
			for(var k : int = 0;k < numConnections;k++) 
			{
				startUnit(_numLoaded + k);
			}
		}

		public function stop() : void
		{
			for(var i : int = 0;i < _totalUnits;i++) 
			{
				var unit : ILoadUnit = _units[_ids[i]];
				var loader : ILoader = unit.loader;
				
				if(!loader.loaded)
					loader.stop();
			}
		}

		override public function destroy() : void
		{
			for(var i : int = 0;i < _totalUnits;i++) 
			{
				var unit : ILoadUnit = _units[_ids[i]];
				var loader : ILoader = unit.loader;
				
				removeLoaderListeners(loader);
				
				loader.destroy();
			}
			
			_totalUnits = 0;
			_numLoaded = 0;
			_progress = 0;
			
			super.destroy();
		}

		public function get progress() : Number
		{
			return _progress;
		}

		public function get bytesLoaded() : uint
		{
			return _bytesLoaded;
		}

		public function get bytesTotal() : uint
		{
			return _bytesTotal;
		}

		public function get numLoaded() : int
		{
			return _numLoaded;
		}

		//--------------------------------------------------------------------------------------------------------------------------------//
		// PROTECTED FUNCTIONS
		//--------------------------------------------------------------------------------------------------------------------------------//
		protected function startUnit(index : int) : void
		{
			var unit : ILoadUnit = _units[_ids[index]];
			if(unit)
			{
				var loader : ILoader = unit.loader;
				
				loader.addEventListener(ProgressEvent.PROGRESS, progress_handler);
				loader.addEventListener(Event.COMPLETE, complete_handler);
				loader.addEventListener(IOErrorEvent.IO_ERROR, error_handler);				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, error_handler);				loader.addEventListener(AsyncErrorEvent.ASYNC_ERROR, error_handler);				loader.addEventListener(ErrorEvent.ERROR, error_handler);
				
				loader.start();
			}
		}

		protected function startNextUnit() : void
		{
			for(var i : int = 0;i < _totalUnits;i++) 
			{
				var unit : ILoadUnit = _units[_ids[i]];
				var loader : ILoader = unit.loader;
				
				if(!loader.invoked && !loader.loaded && (unit.retryTally <= unit.getParam(AssetParam.RETRIES)))
				{
					startUnit(i);
					return;
				}
			}
		}

		protected function retryUnit(loader : ILoader, errorType : String, errorText : String) : void
		{
			var unit : ILoadUnit = loader.loadUnit;
			
			if(unit.retryTally < unit.getParam(AssetParam.RETRIES))
			{
				unit.retryTally++;
				startUnit(_ids.indexOf(unit.id));
			}
			else
			{
				dispatchAssetLoaderEvent(AssetLoaderEvent.ERROR, unit.id, unit.type, null, errorType, errorText);
				
				startNextUnit();
			}
		}

		protected function removeLoaderListeners(loader : ILoader) : void
		{
			loader.removeEventListener(ProgressEvent.PROGRESS, progress_handler);
			loader.removeEventListener(Event.COMPLETE, complete_handler);
			loader.removeEventListener(IOErrorEvent.IO_ERROR, error_handler);
			loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, error_handler);
			loader.removeEventListener(AsyncErrorEvent.ASYNC_ERROR, error_handler);
			loader.removeEventListener(ErrorEvent.ERROR, error_handler);
		}

		protected function dispatchAssetLoaderEvent(type : String, id : String = null, assetType : String = null, data : * = null, errorType : String = null, errorText : String = null) : Boolean
		{
			var event : AssetLoaderEvent = new AssetLoaderEvent(type);
			
			event.id = id;
			event.assetType = assetType;
			event.data = data;
			
			event.progress = _progress;
			event.bytesLoaded = _bytesLoaded;
			event.bytesTotal = _bytesTotal;
			
			event.errorType = errorType;
			event.errorText = errorText;
				
			return dispatchEvent(event);
		}

		//--------------------------------------------------------------------------------------------------------------------------------//
		// PROTECTED HANDLERS
		//--------------------------------------------------------------------------------------------------------------------------------//
		protected function error_handler(event : ErrorEvent) : void 
		{
			retryUnit(ILoader(event.target), event.type, event.text);
		}

		protected function progress_handler(event : ProgressEvent) : void 
		{
			_bytesLoaded = 0;
			_bytesTotal = 0;
			
			for(var i : int = 0;i < _totalUnits;i++) 
			{
				var unit : ILoadUnit = _units[_ids[i]];
				var loader : ILoader = unit.loader;
				
				_bytesLoaded += loader.bytesLoaded;
				_bytesTotal += loader.bytesTotal;
			}
			
			_progress = (_bytesLoaded / _bytesTotal) * 100;
			
			dispatchAssetLoaderEvent(AssetLoaderEvent.PROGRESS);
		}

		protected function complete_handler(event : Event) : void 
		{
			_numLoaded++;
			
			var loader : ILoader = ILoader(event.target);
			var unit : ILoadUnit = loader.loadUnit;
			var eventClass : Class = unit.eventClass;
			
			removeLoaderListeners(loader);
			
			_assets[unit.id] = loader.data;
			
			dispatchAssetLoaderEvent(AssetLoaderEvent.ASSET_LOADED, unit.id, unit.type, loader.data);
			
			dispatchEvent(new eventClass(eventClass.LOADED, unit.id, unit.type, loader.data));
			
			if(_numLoaded == _totalUnits)
				dispatchAssetLoaderEvent(AssetLoaderEvent.COMPLETE, null, null, loader.data);
			else
				startNextUnit();
		}
	}
}