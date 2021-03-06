package org.assetloader.events 
{
	import flash.media.Sound;
	import flash.events.Event;

	/**
	 * @author Matan Uberstein
	 */
	public class SoundAssetEvent extends AbstractAssetEvent 
	{
		public static const LOADED : String = "SOUND_LOADED";

		protected var _sound : Sound;

		public function SoundAssetEvent(type : String, id : String, assetType : String, sound : Sound)
		{
			super(type, id, assetType);
			_sound = sound;
		}

		public function get sound() : Sound
		{
			return _sound;
		}

		override public function clone() : Event 
		{
			return new SoundAssetEvent(type, id, assetType, sound);
		}
	}
}
