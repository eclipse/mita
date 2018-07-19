package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Injector
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable

class ConstraintSystemProvider implements Provider<ConstraintSystem> {
	
	@Inject 
	protected Provider<SymbolTable> symbolTableProvider;
	
	@Inject
	protected Injector injector;
	
	override get() {
		val result = new ConstraintSystem(symbolTableProvider.get());
		injector.injectMembers(result);
		return result;
	}
	
	def get(SymbolTable symbolTable) {
		val result = new ConstraintSystem(symbolTable);
		injector.injectMembers(result);
		return result;
	}
	
}