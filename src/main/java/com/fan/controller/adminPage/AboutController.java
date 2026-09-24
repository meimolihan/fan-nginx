package com.fan.controller.adminPage;

import org.noear.solon.annotation.Controller;
import org.noear.solon.annotation.Mapping;
import org.noear.solon.core.handle.ModelAndView;

import com.fan.utils.BaseController;

@Mapping("/adminPage/about")
@Controller
public class AboutController extends BaseController {

	@Mapping("")
	public ModelAndView index( ModelAndView modelAndView) {

		modelAndView.view("/adminPage/about/index.html");
		return modelAndView;
	}

}
