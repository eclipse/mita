package org.eclipse.mita.program.validation

import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.mita.base.expressions.ArgumentExpression
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.inferrer.StaticValueInferrer
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtext.EcoreUtil2

@Accessors
class MethodCall<T extends NamedElement> {
		final protected ArgumentExpression source
		final protected T t
		final protected EStructuralFeature structFeature
		final protected Operation method
		
		private new(ArgumentExpression ae, Operation op, T t, EStructuralFeature sf) {
			this.source = ae;
			this.t = t;
			this.structFeature = sf;
			this.method = op;
		}
		static dispatch def cons(ArgumentExpression ae, Operation op, SignalInstance si, EStructuralFeature sf) {
			new MethodCallSigInst(ae,op,si,sf);
		}
		static dispatch def cons(ArgumentExpression ae, Operation op, Modality m, EStructuralFeature sf) {
			new MethodCallModality(ae,op,m,sf);
		}
		static dispatch def cons(Object _1, Object _2, Object _3, Object _4) {
			null;
		}
		
		override toString() {
			val setupName = EcoreUtil2.getContainerOfType(t, SystemResourceSetup)?.name ?: EcoreUtil2.getContainerOfType(t, AbstractSystemResource)?.name;
			return '''«source.hashCode»_«setupName».«t.name».«method.name»(«FOR arg : source.arguments SEPARATOR(", ")»«StaticValueInferrer.infer(arg.value, [])?.toString?:"null"»«ENDFOR»)'''
		}	
		override hashCode() {
			toString.hashCode()
		}
		
		override equals(Object arg0) {
			if(arg0 instanceof MethodCall<?>) {
				return toString == arg0.toString;
			}
			return super.equals(arg0)
		}
		
		static class MethodCallSigInst extends MethodCall<SignalInstance> {
			private new(ArgumentExpression ae, Operation op, SignalInstance si, EStructuralFeature sf) {
				super(ae, op, si, sf)
			}
			def SignalInstance getSigInst() {
				return t;
			}
		}
		
		static class MethodCallModality extends MethodCall<Modality> {
			private new(ArgumentExpression ae, Operation op, Modality t, EStructuralFeature sf) {
				super(ae, op, t, sf)
			}
			def Modality getModality() {
				return t;
			}
		}
	}