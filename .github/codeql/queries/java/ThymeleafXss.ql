/**
 * @name XSS via Thymeleaf model attribute
 * @description User-controlled data flows into a Spring Model attribute
 *              which may be rendered unescaped by Thymeleaf (th:utext).
 * @kind path-problem
 * @problem.severity error
 * @security-severity 6.1
 * @precision high
 * @id java/thymeleaf-xss
 * @tags security
 *       external/cwe/cwe-079
 */

import java
import semmle.code.java.dataflow.FlowSources
import semmle.code.java.dataflow.TaintTracking

module ThymeleafXssConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    source instanceof RemoteFlowSource
  }

  predicate isSink(DataFlow::Node sink) {
    exists(MethodCall mc |
      (
        // Spring Model / ModelMap.addAttribute(String, Object)
        mc.getMethod().hasName("addAttribute") and
        mc.getMethod().getDeclaringType().getASourceSupertype*().hasQualifiedName("org.springframework.ui", ["Model", "ModelMap"])
        and sink.asExpr() = mc.getArgument(1)
      )
      or
      (
        // Spring ModelAndView.addObject(String, Object)
        mc.getMethod().hasName("addObject") and
        mc.getMethod().getDeclaringType().hasQualifiedName("org.springframework.web.servlet", "ModelAndView") and
        mc.getMethod().getNumberOfParameters() = 2 and
        sink.asExpr() = mc.getArgument(1)
      )
      or
      (
        // Spring ModelAndView.addObject(Object)
        mc.getMethod().hasName("addObject") and
        mc.getMethod().getDeclaringType().hasQualifiedName("org.springframework.web.servlet", "ModelAndView") and
        mc.getMethod().getNumberOfParameters() = 1 and
        sink.asExpr() = mc.getArgument(0)
      )
    )
  }
}

module ThymeleafXssFlow = TaintTracking::Global<ThymeleafXssConfig>;
import ThymeleafXssFlow::PathGraph

from ThymeleafXssFlow::PathNode source, ThymeleafXssFlow::PathNode sink
where ThymeleafXssFlow::flowPath(source, sink)
select sink.getNode(), source, sink,
  "Unsanitized data from $@ flows into Thymeleaf model, potential XSS.",
  source.getNode(), "user input"