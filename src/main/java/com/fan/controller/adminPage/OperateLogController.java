package com.fan.controller.adminPage;

import org.noear.solon.annotation.Controller;
import org.noear.solon.annotation.Inject;
import org.noear.solon.annotation.Mapping;
import org.noear.solon.core.handle.ModelAndView;

import com.fan.model.OperateLog;
import com.fan.service.OperateLogService;
import com.fan.sqlhelper.bean.Page;
import com.fan.sqlhelper.utils.ConditionAndWrapper;
import com.fan.utils.BaseController;
import com.fan.utils.JsonResult;

@Controller
@Mapping("/adminPage/operateLog")
public class OperateLogController extends BaseController{
	@Inject
	OperateLogService operateLogService;
	
	@Mapping("")
	public ModelAndView index( ModelAndView modelAndView, Page page) {
		setPage(page);
		page = operateLogService.search(page);
		
		modelAndView.put("page", page);
		
		modelAndView.view("/adminPage/operatelog/index.html");
		return modelAndView;
	}
	
	
	@Mapping("detail")
	public JsonResult detail(String id) {
		return renderSuccess(sqlHelper.findById(id, OperateLog.class));
	}
	
	@Mapping("delAll")
	public JsonResult delAll() {
		sqlHelper.deleteByQuery(new ConditionAndWrapper(), OperateLog.class);

		return renderSuccess();
	}
}
