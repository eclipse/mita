package org.eclipse.mita.base.typesystem

import org.eclipse.mita.base.typesystem.types.BoundTypeVariable
import org.eclipse.xtext.naming.QualifiedName

class StdlibTypeRegistry {
	public static val voidType = new BoundTypeVariable(QualifiedName.create(#["stdlib", "void"]));
}
