package mediator.comps
{
import events.SSEvent;

import flash.events.Event;
import flash.events.MouseEvent;

import model.SpriteSheetModel;

import mx.events.CloseEvent;
import mx.events.FlexEvent;
import mx.managers.PopUpManager;

import org.robotlegs.mvcs.Mediator;

import view.comps.SSPreview;

public class SSPreviewMediator extends Mediator
{
	[Inject] public var v:SSPreview;
	
	[Inject] public var ssModel:SpriteSheetModel;
	
	override public function onRegister():void
	{
		eventMap.mapListener(v.playBTN, MouseEvent.CLICK, handler_playBTNclick);
		eventMap.mapListener(v.saveResizeBTN, MouseEvent.CLICK, handler_saveResizeBTNclick);
		eventMap.mapListener(v.frameCropDisplayRBG, FlexEvent.VALUE_COMMIT, handler_frameDisChange);
		eventMap.mapListener(v.resizeOriginCB, FlexEvent.VALUE_COMMIT, handler_resizeOriginCBChange);
		addViewListener(SSPreview.EVENT_FRAME_SIZE_CHANGE, handler_frameSizeChange);
		
		addContextListener(SSEvent.PREVIEW_SS_SHOW, handler_previewShow);
		addContextListener(SSEvent.FRAME_AND_LABEL_CHANGE, handler_framesAndLabelsChange);
		addContextListener(SSEvent.SELECTED_FRAMEINDICES_CHANGE, handler_framesAndLabelsChange);
		addContextListener(SSEvent.OPTIMIZE_SHEET, handler_optimizeSheet);
		
		v.init();
		setPlayEnable();
	}
	
	override public function onRemove():void
	{
		eventMap.unmapListener(v.playBTN, MouseEvent.CLICK, handler_playBTNclick);
		eventMap.unmapListener(v.saveResizeBTN, MouseEvent.CLICK, handler_saveResizeBTNclick);
		eventMap.unmapListener(v.frameCropDisplayRBG, FlexEvent.VALUE_COMMIT, handler_frameDisChange);
		eventMap.unmapListener(v.resizeOriginCB, FlexEvent.VALUE_COMMIT, handler_resizeOriginCBChange);
		removeViewListener(SSPreview.EVENT_FRAME_SIZE_CHANGE, handler_frameSizeChange);
		
		removeContextListener(SSEvent.PREVIEW_SS_SHOW, handler_previewShow);
		removeContextListener(SSEvent.FRAME_AND_LABEL_CHANGE, handler_framesAndLabelsChange);
		removeContextListener(SSEvent.SELECTED_FRAMEINDICES_CHANGE, handler_framesAndLabelsChange);
		removeContextListener(SSEvent.OPTIMIZE_SHEET, handler_optimizeSheet);
		
		v.destroy();
		handler_playBTNclick(null);
	}
	
	protected function handler_optimizeSheet($evt:SSEvent):void
	{
		v.destroyAni();
		//显示优化过的Frame
		v.frameCropDisplayRBG.selectedValue = true;
	}
	
	protected function handler_playBTNclick($event:MouseEvent):void
	{
		ssModel.playing = v.playBTN.selected;
		dispatch(new SSEvent(SSEvent.PREVIEW_SS_PLAY, v.playBTN.selected));
	}
	
	private function handler_saveResizeBTNclick($evt:MouseEvent):void
	{
		dispatch(new SSEvent(SSEvent.PREVIEW_SS_RESIZE_SAVE));
	}
	
	private function handler_previewShow($evt:SSEvent):void
	{
		v.showBmd($evt.info.bmd);
	}
	
	private function handler_frameDisChange($evt:FlexEvent):void
	{
		ssModel.displayCrop = v.frameCropDisplayRBG.selectedValue;
		updateFrame();
		v.frameLabel.text = ssModel.selectedFrmaeNum.toString();
		dispatch(new SSEvent(SSEvent.PREVIEW_SS_CHANGE));
	}
	
	private function handler_resizeOriginCBChange($evt:FlexEvent):void
	{
		//setSaveEnable();
		updateFrame();
	}
	
	private function handler_framesAndLabelsChange($evt:SSEvent):void
	{
		updateFrame();
	}
	
	private function handler_frameSizeChange($evt:Event):void
	{
		updateFrame();
	}
	
	private function updateFrame():void
	{
		v.frameLabel.text = ssModel.selectedFrmaeNum.toString();
		setPlayEnable();
		setSaveEnable();
		ssModel.resizeRect = v.getResizeRect();
	}
	
	private function setSaveEnable():void
	{
		v.saveResizeBTN.enabled = !ssModel.playing && v.resizeOriginCB.selected && ssModel.selectedFrameIndices;
	}
	
	private function setPlayEnable():void
	{
		v.playBTN.enabled = ssModel.selectedFrameIndices && ssModel.selectedFrameIndices.length>1;
	}
}
}