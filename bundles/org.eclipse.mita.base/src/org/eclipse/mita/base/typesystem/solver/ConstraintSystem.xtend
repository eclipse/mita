package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.ArrayList
import java.util.Collections
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint

class ConstraintSystem {
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected final SymbolTable symbolTable;

	@Inject new(Provider<SymbolTable> symbolTableProvider) {
		this.symbolTable = symbolTableProvider.get();
	}
	
	protected new(SymbolTable symbolTable) {
		this.symbolTable = symbolTable;
	}
	
	def addConstraint(AbstractTypeConstraint constraint) {
		this.constraints.add(constraint);
	}
	
	def getSymbolTable() {
		return symbolTable;
	}
	
	def getConstraints() {
		return Collections.unmodifiableList(constraints);
	}
	
	override toString() {
		val res = new StringBuilder()
		
		res.append("Symbols:\n")
		res.append(symbolTable)
		res.append("\n\n")

		res.append("Constraints:\n")
		constraints.forEach[
			res.append("\t")
			res.append(it)
			res.append("\n")
		]
		
		return res.toString
	}
	
	def takeOne() {
		val result = new ConstraintSystem(symbolTable);
		if(constraints.empty) {
			return (null -> result);
		}
		
		result.constraints = constraints.subList(1, constraints.length);
		return constraints.get(0) -> result;
	}
	
}
