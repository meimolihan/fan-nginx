package com.fan.model;

import com.fan.sqlhelper.bean.BaseModel;
import com.fan.sqlhelper.config.Table;

/**
 * 用户远程机器对照表
 * @author CYM
 *
 */
@Table
public class AdminGroup extends BaseModel {
	String adminId;
	String groupId;
	public String getAdminId() {
		return adminId;
	}
	public void setAdminId(String adminId) {
		this.adminId = adminId;
	}
	public String getGroupId() {
		return groupId;
	}
	public void setGroupId(String groupId) {
		this.groupId = groupId;
	}
	
	
}
