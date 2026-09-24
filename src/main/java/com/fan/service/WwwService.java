package com.fan.service;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.model.Www;
import com.fan.sqlhelper.utils.ConditionAndWrapper;
import com.fan.sqlhelper.utils.SqlHelper;

import cn.hutool.core.util.StrUtil;

@Component
public class WwwService {

	@Inject
	SqlHelper sqlHelper;

	public Boolean hasDir(String dir, String id) {
		ConditionAndWrapper conditionAndWrapper = new ConditionAndWrapper().eq("dir", dir);
		if(StrUtil.isNotEmpty(id)) {
			conditionAndWrapper.ne("id", id);
		}
		return sqlHelper.findCountByQuery(conditionAndWrapper, Www.class) > 0;

	}
}
