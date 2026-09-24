package com.fan.controller.api;

import java.io.File;
import java.io.IOException;
import java.util.List;

import org.noear.solon.annotation.Controller;
import org.noear.solon.annotation.Inject;
import org.noear.solon.annotation.Mapping;
import org.noear.solon.core.handle.Context;
import org.noear.solon.core.handle.ModelAndView;
import org.noear.solon.core.handle.UploadedFile;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fan.model.Http;
import com.fan.model.Server;
import com.fan.model.Stream;
import com.fan.model.Upstream;
import com.fan.service.ConfService;
import com.fan.service.SettingService;
import com.fan.sqlhelper.bean.Sort;
import com.fan.sqlhelper.bean.Sort.Direction;
import com.fan.utils.BaseController;
import com.fan.utils.JarUtil;
import com.fan.utils.JsonResult;
import com.fan.utils.ToolUtils;
import com.fan.utils.UpdateUtils;
import com.github.odiszapc.nginxparser.NgxBlock;
import com.github.odiszapc.nginxparser.NgxConfig;
import com.github.odiszapc.nginxparser.NgxDumper;
import com.github.odiszapc.nginxparser.NgxParam;

import cn.hutool.core.io.FileUtil;
import cn.hutool.http.HttpUtil;

/**
 * 文件上传接口
 * 
 * @author CYM
 *
 */
@Mapping("/api/upload")
@Controller
public class UploadController extends BaseController {
	Logger logger = LoggerFactory.getLogger(this.getClass());

	/**
	 * 文件上传
	 * 
	 */
	@Mapping("upload")
	public JsonResult upload(UploadedFile file) {
		try {
			File temp = new File(FileUtil.getTmpDir() + File.separator + file.getName().replace("..", ""));
			file.transferTo(temp);

			return renderSuccess(temp.getPath().replace("\\", "/"));
		} catch (IllegalStateException | IOException e) {
			logger.error(e.getMessage(), e);
		}

		return renderError();
	}

}