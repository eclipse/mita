package org.eclipse.mita.base.typesystem.solver

import java.util.ArrayList
import java.util.Collections
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.AbstractTypeConstraint

class ConstraintSystem {
	protected List<AbstractTypeConstraint> constraints = new ArrayList;
	protected final SymbolTable symbolTable;

	new(SymbolTable symbolTable) {
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
			foo(res, it)
		]
		
		return res.toString
	}
	
	def foo(StringBuilder res, AbstractTypeConstraint it){
			res.append("\t")
			res.append(it)
			res.append("\n")
		
	}
	
	def takeOne() {
		val result = new ConstraintSystem(symbolTable);
		if(constraints.empty) {
			return (null -> result);
		}
		
		result.constraints = constraints.subList(1, constraints.length);
		return constraints.get(0) -> result;
	}
	
	def plus(AbstractTypeConstraint constraint) {
		val result = new ConstraintSystem(symbolTable);
		result.constraints.add(constraint);
		result.constraints.addAll(this.constraints);
		return result;
	}
	
}
