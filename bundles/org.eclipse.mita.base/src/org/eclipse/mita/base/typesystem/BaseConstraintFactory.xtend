package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import java.util.ArrayList
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.IntLiteral
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression
import org.eclipse.mita.base.expressions.NumericalUnaryExpression
import org.eclipse.mita.base.expressions.PrimitiveValueExpression
import org.eclipse.mita.base.expressions.UnaryOperator
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.ExceptionTypeDeclaration
import org.eclipse.mita.base.types.GeneratedType
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.Type
import org.eclipse.mita.base.types.TypeParameter
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeTranslationAdapter
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SymbolTable
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.IntegerType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.Signedness
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.base.util.PreventRecursionAdapter

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected ConstraintSystemProvider constraintSystemProvider;
	
	@Inject
	protected IScopeProvider scopeProvider;
	
	@Inject 
	protected StdlibTypeRegistry typeRegistry;
	
	public override ConstraintSystem create(SymbolTable symbols, EObject context) {
		val result = constraintSystemProvider.get(symbols);
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''BCF: computeConstraints is not implemented for «context.eClass.name»''');
		system.computeConstraintsForChildren(context);
		return TypeVariableAdapter.get(context);
	}
	
	protected def void computeConstraintsForChildren(ConstraintSystem system, EObject context) {
		context.eContents.forEach[ system.computeConstraints(it) ]
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalAddSubtractExpression expr) {
		val leftType = system.computeConstraints(expr.leftOperand);
		val rightType = system.computeConstraints(expr.rightOperand);
		val ourType = TypeVariableAdapter.get(expr);
		system.addConstraint(new SubtypeConstraint(leftType, ourType));
		system.addConstraint(new SubtypeConstraint(rightType, ourType));
		return ourType;
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Type type) {
		system.associate(system.translateTypeDeclaration(type), type);
	}

	protected def AbstractType translateTypeDeclaration(ConstraintSystem system, EObject obj) {
		// some types may have circular dependencies. 
		// To make it easy to solve this we cache type translations, reducing the required number of translations to O(1).
		// So if some translation needs to recurse it can safely do so, as long as at least one member in the recursive circle sets its type translation before recursing.
		val typeTrans = TypeTranslationAdapter.get(obj, [system.doTranslateTypeDeclaration(obj)])
		// if we compile more than once without changes we need to associate again. Hence we always associate here to be safe.
		system.associate(typeTrans, obj);
		// for the same reason we need to iterate over all children of these types.
		// since some of these types might call computeConstrains on their eContainer we need to get out the big guns or have a translateForChildren dispatch method.
		PreventRecursionAdapter.preventRecursion(obj, [|system.computeConstraintsForChildren(obj); return null;]);
		return typeTrans;
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, NativeType type) {
		return typeRegistry.translateNativeType(type)
	}
	
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, PrimitiveType type) {
		new AtomicType(type, type.name);
	}

	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, TypeParameter type) {
		return TypeVariableAdapter.get(type);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, StructureType structType) {
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		return TypeTranslationAdapter.set(structType, new ProdType(structType, structType.name, null, types)) => [
			system.computeConstraints(structType.constructor);	
		];
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val subTypes = new ArrayList();
		return TypeTranslationAdapter.set(sumType, new SumType(sumType, sumType.name, null, subTypes)) => [
			sumType.alternatives.forEach[ sumAlt |
				subTypes.add(system.translateTypeDeclaration(sumAlt));
			];
		]
	}
	 
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, SumAlternative sumAlt) {
		println(sumAlt);
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ].force();
		val prodType = new ProdType(sumAlt, sumAlt.name, system.translateTypeDeclaration(sumAlt.eContainer), types);
		return TypeTranslationAdapter.set(sumAlt, prodType) => [
			system.computeConstraints(sumAlt.constructor);
		];
	}
		
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, GeneratedType genType) {
		val typeParameters = genType.typeParameters;
		val typeArgs = typeParameters.map[ system.computeConstraints(it) ].force();
		val atomicType = new AtomicType(genType, genType.name);
		return TypeTranslationAdapter.set(genType, if(typeParameters.empty) {
			atomicType;
		}
		else {
			new TypeScheme(genType, typeArgs, atomicType);
		}) => [
			system.computeConstraints(genType.constructor);			
		]
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, ExceptionTypeDeclaration genType) {
		return new AtomicType(genType, genType.name);
	}
	
	protected dispatch def AbstractType doTranslateTypeDeclaration(ConstraintSystem system, EObject genType) {
		println('''BCF: No doTranslateTypeDeclaration for «genType.eClass»''');
		return new AtomicType(genType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PresentTypeSpecifier typeSpecifier) {
		val typeArguments = typeSpecifier.typeArguments;
		if(typeSpecifier.type === null) {
			return system.associate(new BottomType(typeSpecifier, "BCF: Unresolved type"));
		}
		if(typeArguments.empty) {
			return system.associate(system.translateTypeDeclaration(typeSpecifier.type), typeSpecifier);
		}
		else {
			if(!(typeSpecifier.type instanceof ComplexType)) {
				return system.associate(new BottomType(typeSpecifier, "BCF: Specified type doesn't have type arguments"))
			}
			if(typeArguments.size !== (typeSpecifier.type as ComplexType).typeParameters.size) {
				return system.associate(new BottomType(typeSpecifier, "BCF: Specified and the type's type arguments differ in length"))
			}
			val vars_typeScheme = system.translateTypeDeclaration(typeSpecifier.type).instantiate();
			val vars = vars_typeScheme.key;
			for(var i = 0; i < Integer.min(typeArguments.size, vars.size); i++) {
				system.addConstraint(new EqualityConstraint(vars.get(i), system.computeConstraints(typeArguments.get(i))));
			}
			return system.associate(vars_typeScheme.value, typeSpecifier);
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypedElement element) {
		return system.associate(system.computeConstraints(element.typeSpecifier), element);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PrimitiveValueExpression t) {
		return system.associate(system.computeConstraints(t.value), t);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NumericalUnaryExpression expr) {
		val operand = expr.operand;
		if(operand instanceof IntLiteral) {
			if(expr.operator == UnaryOperator.NEGATIVE) {
				return system.associate(computeConstraints(system, operand, -operand.value), expr);
			}
			println('''BCF: Unhandled operator: «expr.operator»''')
		}
		println('''BCF: Unhandled operand: «operand.eClass.name»''')
		return system.associate(system.computeConstraints(operand), expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IntLiteral lit) {
		return system.associate(system.computeConstraints(lit, lit.value), lit);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructuralParameter sParam) {
		system.computeConstraints(sParam.accessor);
		return system._computeConstraints(sParam as TypedElement);
	}

	protected def TypeVariable computeConstraints(ConstraintSystem system, EObject source, long value) {
		val sign = if(value < 0) {
			Signedness.Signed;
		} else {
			if(value > 127 && value <= 255) {
				Signedness.Unsigned;
			}
			else if(value > 32767 && value <= 65535) {
				Signedness.Unsigned;
			}
			else if(value > 2147483647L && value <= 4294967295L) {
				Signedness.Unsigned;
			}
			else {
				Signedness.DontCare;
			}
		}
		val byteCount = 
			if(value >= 0 && value <= 255) {
				1;
			}
			else if(value > 255 && value <= 65535) {
				2;
			}
			else if(value > 65535 && value <= 4294967295L) {
				4;
			}
			else if(value >= -128 && value < 0) {
				1;
			} 
			else if(value >= -32768 && value < -128) {
				2;
			}
			else if(value >= -2147483648L && value < -32768) {
				4;
			}
			else {
				return system.associate(new BottomType(source, "BCF: Value out of bounds: " + value));
			}
		return system.associate(new IntegerType(source, byteCount, sign));
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NullTypeSpecifier context) {
		return TypeVariableAdapter.get(context);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('BCF: computeConstraints called on null');
		return null;
	}
	
	protected def associate(ConstraintSystem system, AbstractType t) {
		return associate(system, t, t.origin);
	}
	
	protected def associate(ConstraintSystem system, AbstractType t, EObject typeVarOrigin) {
		if(typeVarOrigin === null) {
			throw new UnsupportedOperationException("BCF: Associating a type variable without origin is not supported (on purpose)!");
		}
		
		val typeVar = TypeVariableAdapter.get(typeVarOrigin);
		if(typeVar != t && t !== null) {
			system.addConstraint(new EqualityConstraint(typeVar, t));
		}
		return typeVar;	
	}	
}