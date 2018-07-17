package org.eclipse.mita.base.typesystem.solver

import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@FinalFieldsConstructor class NormalizedSymbolTable implements ISymbolTable {
	
	protected final QualifiedName normalizer;
	protected final ISymbolTable delegate;
	
	override get(QualifiedName qn) {
		val normalizedName = QualifiedName.create(normalizer.segments + qn.segments);
		return delegate.get(normalizedName) ?: delegate.get(qn);
	}
	
}