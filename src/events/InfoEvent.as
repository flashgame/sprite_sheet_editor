////////////////////////////////////////////////////////////////////////////////
//  zengrong.net
//  创建者:	zrong(zrongzrong@gmail.com)
//  创建时间：2011-8-9
////////////////////////////////////////////////////////////////////////////////

package events
{
import flash.events.Event;

public class InfoEvent extends Event
{
	public static const FRAME_CHANGE:String = 'frameChange';
	public static const LABEL_CHANGE:String = 'labelChange';
	
	public static const SAVE_PIC:String = 'savePic';
	public static const SAVE_META:String = 'saveMeta';
	public static const SAVE_ALL:String = 'saveAll';
	public static const SAVE_SEQ:String = 'saveSeq';
	
	public static const FILE_MANAGER_SELECTION_CHANGE:String = 'selectionChange';
	public static const FILE_MANAGER_SELECTION_CHANGING:String = 'selectionChanging';
	
	public static const IMAGE_PREVIEW_LOAD_COMPLETE:String = 'loadComplete';
	public static const IMAGE_PREVIEW_LOAD_READY:String = 'loadReady';
	
	/**
	 * 建立或优化SpriteSheet
	 */
	public static const BUILD:String = 'build';
	
	public var info:*;
	
	public function InfoEvent($type:String, $info:*=null, $bubbles:Boolean=false, $cancelable:Boolean=false)
	{
		super($type, $bubbles, $cancelable);
		info = $info;
	}
	
	override public function clone():Event
	{
		return new InfoEvent(type, info, bubbles, cancelable);
	}		
}
}