package com.fan.service;

import java.util.List;

import org.noear.solon.annotation.Component;
import org.noear.solon.annotation.Inject;

import com.fan.model.Bak;
import com.fan.model.BakSub;
import com.fan.sqlhelper.bean.Page;
import com.fan.sqlhelper.bean.Sort;
import com.fan.sqlhelper.bean.Sort.Direction;
import com.fan.sqlhelper.utils.ConditionAndWrapper;
import com.fan.sqlhelper.utils.SqlHelper;

@Component
public class BakService {
	@Inject
	SqlHelper sqlHelper;

	public Page<Bak> getList(Page page) {
		return sqlHelper.findPage(new ConditionAndWrapper(), new Sort(Bak::getTime, Direction.DESC), page, Bak.class);
	}

	public List<BakSub> getSubList(String id) {
		return sqlHelper.findListByQuery(new ConditionAndWrapper().eq(BakSub::getBakId, id), BakSub.class);
	}

	public void del(String id) {
		sqlHelper.deleteById(id, Bak.class);
		sqlHelper.deleteByQuery(new ConditionAndWrapper().eq(BakSub::getBakId, id), BakSub.class);
	}

	public void delAll() {
		sqlHelper.deleteByQuery(new ConditionAndWrapper(), Bak.class);
		sqlHelper.deleteByQuery(new ConditionAndWrapper(), BakSub.class);
	}

	public Bak getPre(String id) {
		Bak bak = sqlHelper.findById(id, Bak.class);
		Bak pre = sqlHelper.findOneByQuery(new ConditionAndWrapper().lt(Bak::getTime, bak.getTime()), new Sort(Bak::getTime, Direction.DESC), Bak.class);

		return pre;
	}

}
