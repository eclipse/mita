package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.SymbolTable

class BaseSymbolFactory implements ISymbolFactory {
	
	@Inject
	protected Provider<SymbolTable> symbolTableProvider;
	
	override create(EObject obj) {
		val st = symbolTableProvider.get();
		return st;
	}
	
	dispatch def void addSymbols(SymbolTable table, EObject context) {
		context.eAllContents.forEach[
			table.put(it);
		]
	}
	
	dispatch def void addSymbols(SymbolTable table, Void context) {
		return;
	}
}