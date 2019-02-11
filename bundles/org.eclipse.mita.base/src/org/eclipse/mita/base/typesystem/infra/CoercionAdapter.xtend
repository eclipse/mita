package org.eclipse.mita.base.typesystem.infra

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors

class CoercionAdapter extends AdapterImpl {
	@Accessors
	AbstractType type;
}