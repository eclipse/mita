package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable

class ConstraintSystemProvider implements Provider<ConstraintSystem> {
	
	@Inject 
	Provider<SymbolTable> symbolTableProvider;
	
	override get() {
		return new ConstraintSystem(symbolTableProvider.get());
	}
	
	def get(SymbolTable symbolTable) {
		return new ConstraintSystem(symbolTable);
	}
	
}