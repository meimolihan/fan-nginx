package com.fan.service;

import java.util.List;
import java.util.UUID;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.model.Admin;
import com.fan.model.AdminGroup;
import com.fan.model.Credit;
import com.fan.sqlhelper.bean.Page;
import com.fan.sqlhelper.utils.ConditionAndWrapper;
import com.fan.sqlhelper.utils.SqlHelper;
import com.fan.utils.AuthUtils;
import com.fan.utils.EncodePassUtils;

import cn.hutool.core.util.StrUtil;

@Component
public class AdminService {
	@Inject
	SqlHelper sqlHelper;
	@Inject
	AuthUtils authUtils;

	public Admin login(String name, String pass) {
		Admin admin = sqlHelper.findOneByQuery(new ConditionAndWrapper().eq(Admin::getName, name).eq(Admin::getPass, EncodePassUtils.encode(pass)), Admin.class);

		return admin;
	}

	public Admin getByAutoKey(String autoKey) {
		return sqlHelper.findOneByQuery(new ConditionAndWrapper().eq(Admin::getAutoKey, autoKey), Admin.class);
	}

	public Page search(Page page) {
		page = sqlHelper.findPage(page, Admin.class);

		return page;
	}

	public Long getCountByName(String name) {
		return sqlHelper.findCountByQuery(new ConditionAndWrapper().eq(Admin::getName, name), Admin.class);
	}

	public Long getCountByNameWithOutId(String name, String id) {
		return sqlHelper.findCountByQuery(new ConditionAndWrapper().eq(Admin::getName, name).ne(Admin::getId, id), Admin.class);
	}

	public Admin getOneByName(String name) {
		return sqlHelper.findOneByQuery(new ConditionAndWrapper().eq(Admin::getName, name), Admin.class);
	}

	public Admin makeToken(String id) {
		String token = UUID.randomUUID().toString();
		Admin admin = new Admin();
		admin.setId(id);
		admin.setToken(token);
		admin.setTokenTimeout(System.currentTimeMillis() + 24 * 60 * 60 * 1000l); 
		sqlHelper.updateById(admin);

		return admin;
	}

	public Admin getByToken(String token) {
		Long time = System.currentTimeMillis();
		return sqlHelper.findOneByQuery(new ConditionAndWrapper().eq(Admin::getToken, token).gt(Admin::getTokenTimeout, time), Admin.class); 
	}

	public Admin getByCreditKey(String creditKey) {

		Credit credit = sqlHelper.findOneByQuery(new ConditionAndWrapper().eq(Credit::getKey, creditKey), Credit.class);
		if (credit != null) {
			Admin admin = sqlHelper.findById(credit.getAdminId(), Admin.class);
			return admin;
		}
		return null;
	}

	public List<String> getGroupIds(String adminId) {

		return sqlHelper.findPropertiesByQuery(new ConditionAndWrapper().eq(AdminGroup::getAdminId, adminId), AdminGroup.class, AdminGroup::getGroupId);
	}

	public void addOver(Admin admin, String[] groupIds) {
		sqlHelper.insertOrUpdate(admin);

		sqlHelper.deleteByQuery(new ConditionAndWrapper().eq(AdminGroup::getAdminId, admin.getId()), AdminGroup.class);
		if (admin.getType() == 1 && groupIds != null) {
			for (String id : groupIds) {
				AdminGroup adminGroup = new AdminGroup();
				adminGroup.setAdminId(admin.getId());
				adminGroup.setGroupId(id);
				sqlHelper.insert(adminGroup);
			}
		}
	}

	public void changePassOver(Admin admin) {
		if (admin.getAuth()) {
			Admin adminOrg = sqlHelper.findById(admin.getId(), Admin.class);
			if (StrUtil.isEmpty(adminOrg.getKey())) {
				admin.setKey(authUtils.makeKey());
			}
		} else {
			admin.setKey("");
		}

		if (StrUtil.isNotEmpty(admin.getPass())) {
			admin.setPass(EncodePassUtils.encode(admin.getPass()));
		} else {
			admin.setPass(null);
		}
		sqlHelper.updateById(admin);

	}

}
