package com.fan.service;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.model.Password;
import com.fan.sqlhelper.bean.Page;
import com.fan.sqlhelper.utils.ConditionAndWrapper;
import com.fan.sqlhelper.utils.SqlHelper;

@Component
public class PasswordService {
	@Inject
	SqlHelper sqlHelper;

	public Page search(Page page) {
		page = sqlHelper.findPage(page, Password.class);

		return page;
	}

	public Long getCountByName(String name) {
		return sqlHelper.findCountByQuery(new ConditionAndWrapper().eq("name", name), Password.class);
	}

	public Long getCountByNameWithOutId(String name, String id) {
		return sqlHelper.findCountByQuery(new ConditionAndWrapper().eq("name", name).ne("id", id), Password.class);
	}
}
