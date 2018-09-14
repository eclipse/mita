package org.eclipse.mita.base.typesystem.types

import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@FinalFieldsConstructor
@Accessors
@EqualsHashCode
abstract class NumericType extends AbstractBaseType {
	protected final int widthInBytes;
	
}