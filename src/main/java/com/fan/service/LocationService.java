package com.fan.service;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.sqlhelper.utils.SqlHelper;

@Component
public class LocationService {
	@Inject
	SqlHelper sqlHelper;
}
