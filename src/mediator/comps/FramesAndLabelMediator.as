package mediator.comps
{
import events.SSEvent;

import flash.display.BitmapData;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.filesystem.File;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.ui.Mouse;

import model.FileProcessor;
import model.SpriteSheetModel;

import mx.collections.ArrayCollection;
import mx.collections.ArrayList;
import mx.collections.Sort;
import mx.collections.SortField;
import mx.events.FlexEvent;

import org.robotlegs.mvcs.Mediator;
import org.zengrong.assets.Assets;
import org.zengrong.assets.AssetsEvent;
import org.zengrong.assets.AssetsProgressVO;
import org.zengrong.assets.AssetsType;
import org.zengrong.display.spritesheet.SpriteSheet;
import org.zengrong.display.spritesheet.SpriteSheetMetadata;
import org.zengrong.display.spritesheet.SpriteSheetMetadataType;

import utils.Funs;

import view.comps.FramesAndLabels;

import vo.FrameVO;
import vo.LabelListVO;
import vo.LabelVO;

public class FramesAndLabelMediator extends Mediator
{
	[Inject] public var v:FramesAndLabels;
	
	[Inject] public var file:FileProcessor;
	
	[Inject] public var ssModel:SpriteSheetModel;
	
	/**
	 * 用来载入新加入的帧或者SpriteSheet
	 */
	private var _assets:Assets;
	
	/**
	 * 加入帧的方式，true代表加入的是SpriteSheet，否则是普通图像
	 */
	private var _isAddSSFrame:Boolean;
	
	/**
	 * 使用_assets每载入一个文件，这个索引加一
	 */
	private var _loadAssetsIndex:int=0;
	
	/**
	 * 保存不在Label中的所有帧
	 */
	private var _framesNotInLabels:ArrayCollection;
	
	private var _labelAL:ArrayList;
	
	public var selectedFrameNum:int;		//当前选择的帧编号
	
	override public function onRegister():void
	{
		eventMap.mapListener(v.delBTN,  MouseEvent.CLICK,handler_delBTNclick);
		eventMap.mapListener(v.addSSBTN, MouseEvent.CLICK, handler_selectFile);
		eventMap.mapListener(v.addPicBTN, MouseEvent.CLICK, handler_selectFile);
		eventMap.mapListener(v.labelList, FlexEvent.VALUE_COMMIT,  handler_labelListvalueComit);
		eventMap.mapListener(v.frameDG, FlexEvent.VALUE_COMMIT, handler_frameDGValueCommit);
		eventMap.mapListener(v.addLabelBTN, MouseEvent.CLICK, handler_addLabelBTNclick);
		eventMap.mapListener(v.removeLabelBTN, MouseEvent.CLICK, handler_removeLabelBTNclick);
		eventMap.mapListener(v.renameBTN, MouseEvent.CLICK, handler_renameBTNClick);
		
		addContextListener(SSEvent.PREVIEW_SS_PLAY, handler_ssPreviewPlay);
		addContextListener(SSEvent.PREVIEW_SS_RESIZE_SAVE, handler_saveResizeBTNclick);
		addContextListener(SSEvent.PREVIEW_CLICK, handler_previewClick);
		addContextListener(SSEvent.OPTIMIZE_SHEET_DONE, handler_optimizeDone);
		
		init();
	}
	
	override public function onRemove():void
	{
		eventMap.unmapListener(v.delBTN,  MouseEvent.CLICK,handler_delBTNclick);
		eventMap.unmapListener(v.addSSBTN, MouseEvent.CLICK, handler_selectFile);
		eventMap.unmapListener(v.addPicBTN, MouseEvent.CLICK, handler_selectFile);
		eventMap.unmapListener(v.labelList, FlexEvent.VALUE_COMMIT,  handler_labelListvalueComit);
		eventMap.unmapListener(v.frameDG, FlexEvent.VALUE_COMMIT, handler_frameDGValueCommit);
		eventMap.unmapListener(v.addLabelBTN, MouseEvent.CLICK, handler_addLabelBTNclick);
		eventMap.unmapListener(v.removeLabelBTN, MouseEvent.CLICK, handler_removeLabelBTNclick);
		eventMap.unmapListener(v.renameBTN, MouseEvent.CLICK, handler_renameBTNClick);
		
		removeContextListener(SSEvent.PREVIEW_SS_PLAY, handler_ssPreviewPlay);
		removeContextListener(SSEvent.PREVIEW_SS_RESIZE_SAVE, handler_saveResizeBTNclick);
		removeContextListener(SSEvent.PREVIEW_CLICK, handler_previewClick);
		removeContextListener(SSEvent.OPTIMIZE_SHEET_DONE, handler_optimizeDone);
		
		destroy();
	}
	
	
	public function init():void
	{
		var __meta:SpriteSheetMetadata = ssModel.adjustedSheet.metadata;
		_framesNotInLabels = new ArrayCollection();
		var __frame:FrameVO = null;
		var i:int=0;
		for (i = 0; i < __meta.totalFrame; i++) 
		{
			__frame = new FrameVO();
			__frame.frameNum = i;
			__frame.frameName = __meta.hasName? __meta.names[i]:null;
			__frame.frameRect = __meta.frameRects[i];
			__frame.originRect = __meta.originalFrameRects[i];
			_framesNotInLabels.addItem(__frame);
		}
		
		_labelAL = new ArrayList();
		v.labelList.dataProvider = _labelAL;
		v.labelCB.selected = __meta.hasLabel;
		if(__meta.hasLabel)
		{
			var __label:String = '';
			var __framesIndex:Array = null;
			var __framesInLabel:ArrayList = null;
			//建立Label后，要从frameAL列表中删除的帧的索引（因为这些帧被加入到labelAL中了）
			var __toDelFrames:Array = [];
			for (i = 0; i < __meta.labels.length; i++) 
			{
				__label = __meta.labels[i];
				__framesIndex = __meta.labelsFrame[__label];
				__framesInLabel = new ArrayList();
				for (var k:int = 0; k < __framesIndex.length; k++) 
				{
					__framesInLabel.addItem(_framesNotInLabels.getItemAt(__framesIndex[k]));
					__toDelFrames.push(__framesIndex[k]);
				}
				_labelAL.addItem(new LabelVO(__label, __framesInLabel));
			}
			//从最后一个要删除的帧开始删除（这样就不会影响到_framesNotInLabels的顺序，确保删除的成功）
			__toDelFrames.sort(Array.NUMERIC);
			while(__toDelFrames.length>0)
				_framesNotInLabels.removeItemAt(__toDelFrames.pop());
		}
		//如果当前有不在Label中的帧，就显示它们
		if(_framesNotInLabels.length>0)
		{
			v.selectedFrameIndices = new Vector.<int>;
			for (var j:int = 0; j < _framesNotInLabels.length; j++) 
			{
				v.selectedFrameIndices[j] = j;
			}
			refreshFrameDG();
			trace('init:', v.selectedFrameIndices);
			v.frameDG.selectedIndices = v.selectedFrameIndices;
			selectFrameChange();
		}
		if(!_assets)
		{
			_assets = new Assets();
			_assets.addEventListener(AssetsEvent.COMPLETE, handler_assetsComp);
			_assets.addEventListener(AssetsEvent.PROGRESS, handler_assetsProgress);
		}
		v.init();
	}
	
	public function destroy():void
	{
		if(_framesNotInLabels) _framesNotInLabels.removeAll();
		_framesNotInLabels = null;
		if(_assets)
		{
			_assets.removeEventListener(AssetsEvent.PROGRESS, handler_assetsProgress);
			_assets.removeEventListener(AssetsEvent.COMPLETE, handler_assetsComp);
			_assets = null;
		}
		if(_labelAL)	_labelAL.removeAll();
		_labelAL = null;
		v.selectedFrameIndices = null;
		selectFrameChange();
		v.destroy();
		play(false);
	}
	
	private function play($play:Boolean):void
	{
		v.play($play);
		ssModel.playing = v.playing;
	}
	
	/**
	 * 载入一个图像文件成功后，将其加入spritesheet中
	 */
	private function handler_assetsProgress($evt:AssetsEvent):void
	{
		var __vo:AssetsProgressVO = $evt.vo;
		if(__vo.whole && __vo.done)
		{
			trace('FrameAndLabels.handler_assetsProgress:',__vo.toString());
			if(_isAddSSFrame)
				addSSToSheet(__vo);
			else
				addPicToSheet(__vo);
		}
	}
	
	private function handler_assetsComp($evt:AssetsEvent):void
	{
		//labelList.selectedIndex = labelAL.length - 1;
		refreshFrameDG();
		dispatchOptimize();
	}
	
	/**
	 * 获取metadata中需要的label数据
	 */
	public function getLabels():LabelListVO
	{
		var __vo:LabelListVO = new LabelListVO();
		__vo.hasLabel = v.labelCB.selected && _labelAL.length>0;
		if(__vo.hasLabel)
		{
			__vo.labels = new Vector.<String>(_labelAL.length);
			__vo.labelsFrame = {};
			var __labelItem:LabelVO = null;
			for (var i:int = 0; i < _labelAL.length; i++) 
			{
				__labelItem = _labelAL.getItemAt(i) as LabelVO;
				__vo.labels[i] = __labelItem.name;
				__vo.labelsFrame[__labelItem.name] = __labelItem.getFramesIndex();
			}
		}
		return __vo;
	}
	
	
	public function selectFrameChange():void
	{
		ssModel.selectedFrameIndices = v.selectedFrameIndices;
		var __selectedFrame:Vector.<FrameVO> = new Vector.<FrameVO>;
		for (var i:int = 0; ssModel.selectedFrameIndices && i < ssModel.selectedFrameIndices.length>0; i++) 
		{
			__selectedFrame[i] = v.getFrameItemAt(ssModel.selectedFrameIndices[i]);
		}
		dispatch(new SSEvent(SSEvent.SELECTED_FRAMEINDICES_CHANGE, __selectedFrame));
	}
	
	/**
	 * 将选择的SpriteSheet加入到Sheet中
	 */
	private function addSSToSheet($vo:AssetsProgressVO):void
	{
		var __ss:SpriteSheet = _assets.getSpriteSheet($vo.name);
		//当前Sheet的总帧数
		var __sheetTotal:int = ssModel.originalSheet.metadata.totalFrame;
		//当前Sheet的最后一帧的Rect
		var __lastFrameRect:Rectangle = ssModel.originalSheet.metadata.frameRects[__sheetTotal-1];
		//加入的sheet的总帧数
		var __addSheetTotal:int = __ss.metadata.totalFrame;
		var __rect:Rectangle = null;
		var __origRect:Rectangle = null;
		var __bmd:BitmapData = null;
		var __frame:FrameVO = null;
		var __name:String = null;
		//所有帧的信息数组，保存起来，后面方便处理Label
		var __frameVOs:Vector.<FrameVO> = new Vector.<FrameVO>;
		for(var i:int=0;i<__addSheetTotal;i++)
		{
			__rect = __ss.metadata.frameRects[i].clone();
			//将加入的Sheet的所有帧的位置都放到当前Sheet的最后一行换行后的位置
			__rect.y += __lastFrameRect.bottom;
			__origRect = __ss.metadata.originalFrameRects[i].clone();
			__bmd = __ss.getBMDByIndex(i);
			
			__frame = new FrameVO();
			__frame.frameNum = __sheetTotal + i;
			__frame.frameRect = __rect;
			__frame.originRect = __origRect;
			
			//如果新加入的sheet有name，就直接使用。这里不必判断Sheet是否使用name，先加进来，最后用不用是保存时候的事情。
			if(__ss.metadata.hasName)
				__frame.frameName = __ss.metadata.names[i];
				//否则就自动根据资源名称和当前索引生成name
			else
				__frame.frameName = $vo.name + '_' + i;
			__name = __frame.frameName;
			__frameVOs[i] = __frame;
			ssModel.addOriginalFrame(__bmd, __rect, __origRect, __name);
		}
		//如果加入的Sheet包含Label，就使用它
		if(__ss.metadata.hasLabel)
		{
			//让当前的SpriteSheet支持Label，使用adjustedSheet即可
			ssModel.adjustedSheet.metadata.hasLabel = true;
			//打开Label面板
			v.labelCB.selected = true;
			var __labelList:Array = null;
			var __newLabelList:Array = null;
			var __labelFrameAL:ArrayList = null;
			//保存加入的Sheet中Label中某一帧的索引，这个索引值是原始的，没有加入当前Sheet总帧数的值
			var __frameNum:int = 0;
			for(var __labelName:String in __ss.metadata.labelsFrame)
			{
				__labelList = __ss.metadata.labelsFrame[__labelName];
				var __curSheetLabelsFrame:Object = ssModel.adjustedSheet.metadata.labelsFrame;
				
				//如果当前的Sheet包含Label，且新的Label中有与当前Label重名的，就不加入同名Label
				if(__curSheetLabelsFrame && (__labelName in __curSheetLabelsFrame)) continue;
				__newLabelList = [];
				__labelFrameAL = new ArrayList();
				//旧的label的index索引，要加上原始的sheet的总帧数，因为帧是加到末尾的
				for(var k:int=0;k<__labelList.length;k++)
				{
					__frameNum = __labelList[k];
					__newLabelList[k] = __frameNum+__sheetTotal;
					//从所有帧列表中删除当前Label中所属的帧，加入到Label列表
					__labelFrameAL.addItem(__frameVOs[__frameNum]);
					__frameVOs[__frameNum] = null;
				}
				_labelAL.addItem(new LabelVO(__labelName, __labelFrameAL));
			}
		}
		
		//将不在Label中的Frame，以及Label出现重名的Frame都加入_framesNotInLabels列表
		for(var l:int=0;l<__frameVOs.length;l++)
		{
			__frame = __frameVOs[l];
			if(__frame != null) _framesNotInLabels.addItem(__frame);
		}
	}
	
	/**
	 * 将选择的图像加入到Sheet中
	 */
	private function addPicToSheet($vo:AssetsProgressVO):void
	{
		var __bmd:BitmapData = _assets.getBitmapData($vo.name);
		var __total:int = ssModel.originalSheet.metadata.totalFrame;
		//基于最后一帧的rect位置，横向移动rect
		var __rect:Rectangle = ssModel.originalSheet.metadata.frameRects[__total-1].clone();
		__rect.x += __rect.width;
		__rect.width = __bmd.width;
		__rect.height = __bmd.height;
		//原始的rect，不裁切
		var __origRect:Rectangle = new Rectangle(0,0,__bmd.width, __bmd.height);
		//加入帧列表
		var __frame:FrameVO = new FrameVO();
		__frame.frameNum = __total;
		__frame.frameName = $vo.name;
		__frame.frameRect = __rect;
		__frame.originRect = __origRect;
		_framesNotInLabels.addItem(__frame);
		ssModel.addOriginalFrame(__bmd, __rect, __origRect, __frame.frameName);
	}
	
	/**
	 * 根据选择情况刷新frameDG的显示
	 */
	public function refreshFrameDG():void
	{
		var i:int=0;
		if(!_framesNotInLabels.sort)
		{
			_framesNotInLabels.sort = new Sort();
			_framesNotInLabels.sort.fields = [new SortField('frameNum', false, false)];
		}
		_framesNotInLabels.refresh();
		v.newFrameAC();
		//若选择的是label，就显示该Label中的所有帧
		if(v.labelCB.selected && v.labelList.selectedIndex != -1)
		{
			var __framesInLabel:ArrayList = LabelVO(v.labelList.selectedItem).frames;
			v.addFrameAll(__framesInLabel);
			var __indices:Vector.<int> = new Vector.<int>;
			for (var j:int = 0; j < __framesInLabel.length; j++) 
			{
				__indices[j] = j;
			}
			v.frameDG.selectedIndices = __indices;
		}
			//否则显示不在Label中的所有帧
		else
		{
			v.addFrameAll(_framesNotInLabels);
			v.frameDG.selectedIndex = -1;
		}
	}
	
	protected function handler_labelListvalueComit($event:FlexEvent):void
	{
		refreshFrameDG();
	}
	
	protected function handler_frameDGValueCommit($event:FlexEvent):void
	{
		//只有不在播放状态，才更新选择的帧列表
		if(!v.playing)
		{
			v.selectedFrameIndices = v.frameDG.selectedIndices.concat();
			//获取到的Vector是降序的，倒转它
			v.selectedFrameIndices.sort(Array.NUMERIC);
			trace('更新indices:', v.selectedFrameIndices);
			selectFrameChange();
		}
		selectedFrameNum = v.frameDG.selectedIndex==-1? -1 : FrameVO(v.frameDG.selectedItem).frameNum;
		trace('dgValueCommit:', selectedFrameNum);
		
		//Lable修改的时候更新动画预览
		ssModel.selectedFrameIndex = v.selectedFrameIndex;
		ssModel.selectedFrmaeNum = selectedFrameNum;
		if(v.selectedFrameIndex > -1)
		{
			dispatch(new SSEvent(SSEvent.PREVIEW_SS_CHANGE));
		}
	}
	
	private function handler_renameBTNClick($evt:MouseEvent):void
	{
		var __item:Object = _labelAL.getItemAt(v.labelList.selectedIndex);
		__item.name = v.labelInput.text;
		_labelAL.setItemAt(__item, v.labelList.selectedIndex);
	}
	
	protected function handler_addLabelBTNclick($event:MouseEvent):void
	{
		//trace(frameDG.selectedIndex, frameDG.selectedItem, frameDG.selectedItems);
		if(!v.frameDG.selectedItem)
		{
			Funs.alert('请先选择帧！');
			v.addLabelBTN.enabled = false;
			return;
		}
		for (var i:int = 0; i < _labelAL.length; i++) 
		{
			if(LabelVO(_labelAL.getItemAt(i)).name == v.labelInput.text)
			{
				Funs.alert('Label不允许重复！');
				return;
			}
		}
		var __framesInLabel:Vector.<FrameVO> =  Vector.<FrameVO>(v.frameDG.selectedItems.concat());
		__framesInLabel.sort(function($a:FrameVO, $b:FrameVO):int
		{
			return $a.frameNum - $b.frameNum;
		}
		);
		var __al:ArrayList = new ArrayList();
		while(__framesInLabel.length>0)
		{
			var __item:FrameVO = __framesInLabel.shift() as FrameVO;
			__al.addItem(__item);
			trace('向Label添加帧：', __item.frameNum);
			//删除_framesNotInLabels中的帧，ArrayCollection没有removeItem，真杯具
			var __itemIndex:int = _framesNotInLabels.getItemIndex(__item);
			_framesNotInLabels.removeItemAt(__itemIndex);
		}
		_labelAL.addItem(new LabelVO(v.labelInput.text, __al));
		v.labelList.selectedIndex = _labelAL.length - 1;
		refreshFrameDG();
	}
	
	protected function handler_removeLabelBTNclick($event:MouseEvent):void
	{
		var __item:LabelVO = v.labelList.selectedItem as LabelVO;
		for (var i:int = 0; i < __item.frames.length; i++) 
		{
			var __frame:FrameVO = __item.frames.getItemAt(i) as FrameVO;
			_framesNotInLabels.addItem(__frame);
		}
		_labelAL.removeItem(__item);
		refreshFrameDG();
	}
	
	protected function handler_delBTNclick($event:MouseEvent):void
	{
		v.nextBTN.enabled = false;
		v.prevBTN.enabled = false;
		if(!v.frameDG.selectedItem)
		{
			//spark的组件怎么这么多绑定bug TNND……
			Funs.alert('请先选择要删除的帧。');
			v.delBTN.enabled = false;
			return;
		}
		while(v.selectedFrameIndices.length>0)
		{
			var __delItem:FrameVO = v.getFrameItemAt(v.selectedFrameIndices.pop());
			ssModel.originalSheet.removeFrameAt(__delItem.frameNum);
			ssModel.adjustedSheet.removeFrameAt(__delItem.frameNum);
			trace('删除Sheet与adjustedSheet中的帧，删除后：', ssModel.originalSheet.metadata.totalFrame, ssModel.adjustedSheet.metadata.totalFrame);
			//若选择了Label，在labelVO中删除
			if(v.labelCB.selected && v.labelList.selectedIndex!=-1)
			{
				//删除labelVO中的当前帧
				LabelVO(v.labelList.selectedItem).frames.removeItem(__delItem);
			}
				//如果没有选择label，就在_frameNotInLabels中删除
			else
			{
				var __index:int = _framesNotInLabels.getItemIndex(__delItem);
				_framesNotInLabels.removeItemAt(__index);
			}
			//修改所有label中的帧的编号
			for(var i:int=0;i<_labelAL.length;i++)
			{
				var __labelItem:LabelVO = _labelAL.getItemAt(i) as LabelVO;
				v.refreshFrameNum(__labelItem.frames, __delItem.frameNum);
			}
			//修改不在label中的帧的编号
			v.refreshFrameNum(_framesNotInLabels, __delItem.frameNum);
		}
		v.selectedFrameIndices = null;
		selectFrameChange();
		//刷新frameDG的显示
		refreshFrameDG();
		//通知SSPanel已经删除了帧，SSPanel根据需求重新生成
		dispatchOptimize();
	}
	
	
	private function handler_ssPreviewPlay($evt:SSEvent):void
	{
		play($evt.info);
	}
	
	private function handler_selectFile($evt:Event):void
	{
		_isAddSSFrame = ($evt.currentTarget == v.addSSBTN);
		file.addToSS(fun_addToSS);
	}
	
	/**
	 * 选择加入的图像文件后，调用的方法
	 */
	private function fun_addToSS($filelist:Array):void
	{
		var __fileList:Array = $filelist;
		var __file:File = null;
		var __urls:Array = [];
		var __urlobj:Object = null;
		for(var i:int=0;i<__fileList.length;i++)
		{
			__file = __fileList[i] as File;
			__urlobj = {url:__file.url};
			__urlobj.ftype = __file.extension;
			if(_isAddSSFrame)
			{
				__urlobj.ftype = AssetsType.SPRITE_SHEET;
				__urlobj.mtype = SpriteSheetMetadataType.XML;
			}
			__urls.push(__urlobj);
		}
		_assets.load(__urls);
	}
	
	private function dispatchOptimize():void
	{
		dispatch(new SSEvent(SSEvent.OPTIMIZE_SHEET));
	}
	
	protected function handler_saveResizeBTNclick($evt:SSEvent):void
	{
		//修改选择的帧的初始大小，同时直接重新绘制该帧的bitmapData
		var __rect:Rectangle = ssModel.resizeRect;
		if(v.selectedFrameIndices)
		{
			var __frame:FrameVO= null;
			var __bmd:BitmapData = null;
			var __point:Point = new Point(0,0);
			var __frameNum:int = 0;
			for (var i:int = 0; i < v.selectedFrameIndices.length; i++) 
			{
				__bmd = new BitmapData(__rect.width, __rect.height, true, 0x00000000);
				__frame = v.getFrameItemAt(v.selectedFrameIndices[i]);
				//设置frameVO中保存的两个rect的值，frameVO中的两个rect是从adjustedSheet获取而来，而且使用的是引用，因此同时修改了Global中的adjustedSheet的值
				__frame.frameRect.width = __rect.width;
				__frame.frameRect.height = __rect.height;
				__frame.originRect.x = 0;
				__frame.originRect.y = 0;
				__frame.originRect.width = __rect.width;
				__frame.originRect.height = __rect.height;
				//根据调整的大小重新绘制当前帧的bmd
				__bmd.copyPixels(ssModel.originalSheet.getBMDByIndex(__frame.frameNum), __rect, __point, null, null, true);
				//设置adjustedSheet中的bmd，由于已经修改了两个rect的值，这里就不需要再重置rect
				ssModel.addAdjustedFrameAt(__frame.frameNum, __bmd);
				//设置sheet中的bmd，同时设置两个rect
				ssModel.addOriginalFrameAt(__frame.frameNum,__bmd.clone(), __frame.frameRect.clone(), __frame.originRect.clone());
				v.refreshFrame();
			}
		}
		dispatchOptimize();
		//ani.destroy();
	}
	
	private function handler_previewClick($evt:SSEvent):void
	{
		v.findFrameByPoint($evt.info as Point);
	}
	
	private function handler_optimizeDone($evt:SSEvent):void
	{
		init();
	}
}
}