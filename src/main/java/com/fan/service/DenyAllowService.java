package com.fan.service;

import java.util.LinkedHashSet;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.model.DenyAllow;
import com.fan.sqlhelper.bean.Page;
import com.fan.sqlhelper.utils.SqlHelper;

import cn.hutool.core.util.StrUtil;

@Component
public class DenyAllowService {
	@Inject
	SqlHelper sqlHelper;

	public Page search(Page page) {
		page = sqlHelper.findPage(page, DenyAllow.class);

		return page;
	}

	public void removeSame(DenyAllow denyAllow) {
		if (StrUtil.isNotEmpty(denyAllow.getIp())) {
			LinkedHashSet<String> set = new LinkedHashSet<String>();

			String[] ips = denyAllow.getIp().split("\n");

			for (String ip : ips) {
				set.add(ip.trim());
			}

			denyAllow.setIp(StrUtil.join("\n", set));
		}
	}


}
