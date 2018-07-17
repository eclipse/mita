package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
abstract class AbstractType {
	protected final String name;
	
	abstract def AbstractType replace(AbstractType from, AbstractType with);
	
	abstract def Iterable<FreeTypeVariable> getFreeVars();
	
}