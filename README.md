# Modelo de probabilidad de recesión en EE. UU. — horizonte de 12 meses

[![Licencia: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Abrir en Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/owoc9103/Informe_recesion/blob/main/Recession_Probability_Model.ipynb)
[![Informe semanal](https://github.com/owoc9103/Informe_recesion/actions/workflows/daily_recession_report.yml/badge.svg)](https://github.com/owoc9103/Informe_recesion/actions/workflows/daily_recession_report.yml)

Ensamble de cinco modelos que estima la probabilidad de que Estados Unidos entre en recesión en los próximos 12 meses, con 37 indicadores de FRED en ocho categorías macroeconómicas. Cada lunes genera un informe para comité de inversión, en español y con los gráficos incrustados. El texto lo redacta Qwen 3.8 27B a través de la API de Groq.

El marco académico es el de Estrella y Mishkin (1996, 1998), el mismo que usan la Fed de Nueva York y la Fed de Cleveland. El código de origen está en [SecondOrderEdge/Recession_Probability_Model](https://github.com/SecondOrderEdge/Recession_Probability_Model). Esta copia cambia la redacción del correo: usa Groq en lugar de Claude y deja el informe en español. Los códigos de las variables (`SPREAD`, `FEDFUNDS`, `HSN1F_YOY` y el resto) no se traducen.

---

## Qué hace

Cada lunes por la mañana, un flujo de GitHub Actions:

1. Descarga los datos más recientes de FRED, la base del Banco de la Reserva Federal (37 indicadores).
2. Estima una regresión probit con selección de variables por BIC y restricciones de signo económico.
3. Calcula la probabilidad del ensamble de cinco modelos, con intervalos de confianza por bootstrap.
4. Genera 7 gráficos: tendencia de la probabilidad, tablero de indicadores, comparación de modelos, umbrales de sensibilidad y contexto histórico.
5. Envía la salida del modelo a Qwen, que escribe el memorando en español.
6. Manda el memorando por correo, con los gráficos incrustados.

El ensamble es el promedio simple de cinco modelos distintos: NY Fed (solo `SPREAD`), Wright (dos factores), multivariado seleccionado por BIC, forma cerrada de Estrella-Mishkin y el Markov-switching de Chauvet-Piger.

---

## Arranque rápido

### Opción A: Google Colab (exploración interactiva)

1. Abre `Recession_Probability_Model.ipynb` en [Google Colab](https://colab.research.google.com/).
2. Pide una clave gratuita de FRED en https://fred.stlouisfed.org/docs/api/fred/.
3. Ejecuta todas las celdas. El cuaderno instala dependencias, descarga datos, estima y grafica.

### Opción B: informe semanal automático

1. El flujo vive en este repositorio: [owoc9103/Informe_recesion](https://github.com/owoc9103/Informe_recesion).

2. **Agrega los secretos de GitHub** (Settings > Secrets and variables > Actions):

   | Secreto | ¿Obligatorio? | Descripción |
   |---------|---------------|-------------|
   | `FRED_API_KEY` | Sí | Clave gratuita de https://fred.stlouisfed.org/docs/api/fred/ |
   | `GROQ_API_KEY` | Sí | Clave de https://console.groq.com/keys. El modelo es `qwen/qwen3.8-27b` |
   | `MAIL_USERNAME` | No | Dirección de Gmail que envía el informe |
   | `MAIL_PASSWORD` | No | Contraseña de aplicación de Gmail (https://myaccount.google.com/apppasswords) |
   | `MAIL_PORT` | No | Puerto SMTP, normalmente `587` |
   | `EMAIL_TO` | No | Destinatarios, separados por coma |

3. **Permisos de escritura:** Settings > Actions > General > Workflow permissions > Read and write permissions. Sin eso, el flujo no puede guardar el resumen semanal.

4. **Activa el flujo:** pestaña Actions > "Weekly Recession Probability Report".

5. **Prueba:** pulsa "Run workflow" para lanzarlo en el momento. El cron corre cada lunes a las 14:00 UTC (9:00, hora de Colombia).

Sin credenciales de Gmail, el informe queda como archivo HTML en los artefactos del flujo.

En el plan gratuito de Groq el modelo no recibe las imágenes: cada gráfico cuenta como unos 2.000 tokens y el tope de entrada es 7.000. Qwen redacta a partir del JSON y los gráficos se incrustan después, en el correo.

### Opción C: ejecución local

En Windows, desde esta carpeta, con las claves en un archivo `.env` (no se sube a git):

```powershell
.\ejecutar_local.ps1
```

O, paso a paso:

```powershell
pip install -r requirements.txt
python automation/daily_report.py      # Descarga datos, estima y genera gráficos
python automation/generate_email.py    # Redacta el correo con Groq y lo envía
```

Los archivos de salida quedan en `automation/output/`.

---

## Cómo funciona

### El marco probit

El modelo estadístico central es una regresión probit:

**P(Recesión_{t+12} = 1 | X_t) = Phi(a_0 + a_1 * X_t)**

Phi(.) es la función de distribución de la normal estándar, X_t es el vector de indicadores observados en t, y el horizonte es de 12 meses. El probit convierte una combinación lineal de indicadores en una probabilidad entre 0 y 1. Equivale a un modelo de variable latente: un índice no observado de "salud económica" cruza un umbral cuando hay recesión.

### Ensamble de cinco modelos

La probabilidad que se destaca no depende de una sola especificación. Es el promedio con pesos iguales de cinco modelos:

| Modelo | Variables | Metodología | Referencia |
|--------|-----------|-------------|------------|
| **Base NY Fed** | Solo el diferencial de la curva | Probit reestimado | Estrella y Mishkin (1998) |
| **Extensión de Wright** | `SPREAD` + tasa de fondos federales | Probit reestimado | Wright (2006) |
| **Seleccionado por BIC** | Conjunto óptimo según los datos | Probit reestimado con restricciones de signo | BIC hacia adelante |
| **Estrella-Mishkin** | Diferencial de la curva | Forma cerrada con parámetros de 2006 | Estrella y Trubin (2006) |
| **Chauvet-Piger** | Modelo de cambio de régimen | Serie independiente de FRED (`RECPROUSM156N`) | Chauvet y Piger |

Así se diversifica la complejidad (de 1 variable a 7 o más), la forma de estimar (reestimar, dejar los parámetros fijos, o usar Markov-switching) y la pregunta de fondo: si la curva basta o si un modelo de varios factores aporta algo.

### Selección de variables: BIC con restricciones de signo

Las recesiones son raras (cerca del 15 % de los meses desde 1967). Con más de 30 candidatas y apenas unos 6 episodios en la muestra, el riesgo principal es el sobreajuste. La selección es BIC hacia adelante, con tres controles:

1. **Penalización BIC.** Castiga la complejidad más que el AIC. Berge (2014) mostró que esa parsimonia domina en el horizonte de 12 meses.
2. **Detección de separación.** Rechaza combinaciones con separación casi completa (coeficientes mayores que 100, errores estándar indefinidos o pseudo R² mayor que 0,99).
3. **Restricciones de signo.** El coeficiente tiene que coincidir con la teoría antes de aceptar la variable:

   | Indicador | Signo exigido | Lógica económica |
   |-----------|---------------|------------------|
   | SPREAD | Negativo | Menor diferencial, mayor riesgo de recesión |
   | UNRATE_CHG3 | Positivo | Más desempleo, mayor riesgo de recesión |
   | UMCSENT | Negativo | Peor sentimiento, mayor riesgo de recesión |
   | BUSLOANS_YOY | Negativo | Contracción del crédito, mayor riesgo de recesión |

Si ninguna combinación pasa los tres controles, el modelo vuelve a la especificación de Wright: diferencial más tasa de fondos federales.

### Construcción de la variable dependiente

Se puede configurar de dos maneras:

- **Puntual** (`"point"`): y_t = 1 si hay recesión en el mes t+12. Es la definición de la Fed de Nueva York.
- **En la ventana** (`"window"`): y_t = 1 si hay recesión en cualquier mes entre t+1 y t+12. Da probabilidades más altas y más persistentes.

La Fed de Boston (2020) documentó una dispersión considerable entre las dos. El cuaderno las compara lado a lado.

### Transformaciones

Las transformaciones están en el diccionario `SERIES_CONFIG`:

- **Variación porcentual interanual** (`"yoy"`): para series en nivel no estacionarias (INDPRO, precios, viviendas iniciadas, nóminas). Quita la tendencia y conserva el ciclo.
- **Niveles** (`"level"`): para series estacionarias o acotadas (diferenciales, tasas, índices normalizados).
- **Variables derivadas:** `SPREAD` (= GS10 − TB3MS), para tener historia mensual anterior a 1982; `UNRATE_CHG3`, el impulso del desempleo al estilo de la regla de Sahm.

### Estimación: ventana expansiva

Se usa ventana expansiva, no móvil. Las recesiones son demasiado escasas para que una ventana móvil dé estimaciones estables. El mínimo de entrenamiento es 120 meses (10 años). La probabilidad de cada mes sale de un modelo entrenado solo con la información disponible en ese momento: no hay sesgo de mirada al futuro.

### Controles de robustez

El cuaderno incluye cinco controles:

1. **Intervalo bootstrap al 90 %.** 1.000 remuestreos para cuantificar la incertidumbre del estimador puntual.
2. **Dejar fuera una recesión.** Entrena con todas menos una y comprueba si detecta el episodio excluido.
3. **Probit penalizado.** Regresión logística con regularización L2, para ver si la cuasi-separación distorsiona las estimaciones.
4. **Consenso entre modelos.** Mide el acuerdo de las cinco especificaciones.
5. **Umbrales de sensibilidad.** Búsqueda binaria del valor exacto de cada indicador que llevaría la probabilidad al 30 % o al 50 %.

### Atribución de la tendencia

El informe semanal descompone el cambio de probabilidad a 24 meses en el aporte de cada indicador. El efecto parcial es el coeficiente por el cambio de la variable por la densidad normal en el índice lineal actual. Así se ve qué indicador está empujando la probabilidad hacia arriba o hacia abajo.

---

## Universo de datos — 37 series de FRED en 8 categorías

| Categoría | Series | Transformación |
|-----------|--------|----------------|
| **Actividad nacional** | CFNAI, CFNAIMA3, GDPC1, USSLIND | Nivel / interanual |
| **Industria** | INDPRO, BSCICP02USM460S (confianza manufacturera OCDE), TCU, DGORDER, IPMAN | Interanual / nivel |
| **Consumo** | UMCSENT, PCECC96, DSPIC96, RSAFS | Nivel / interanual |
| **Mercado laboral** | UNRATE, ICSA, PAYEMS, JTSJOL | Nivel / interanual |
| **Inflación** | CPIAUCSL, PCEPILFE, PCEPI, CPILFESL, PPIACO | Interanual |
| **Vivienda** | HOUST, PERMIT, HSN1F, CSUSHPISA | Interanual |
| **Banca y crédito** | BAA10YM, BUSLOANS, DRALACBS, DRTSCILM | Nivel / interanual |
| **Rendimientos** | T10Y3M, T10Y2Y, GS10, TB3MS, FEDFUNDS | Nivel |

Las series que no son mensuales se reagrupan: la semanal (ICSA) al promedio mensual, las diarias (T10Y3M, T10Y2Y) al cierre de mes, y las trimestrales (GDPC1, DRALACBS, DRTSCILM) se rellenan hacia adelante hasta quedar mensuales. Si una variable cubre menos del 80 % del periodo objetivo, se excluye, para que una serie corta no encoja toda la muestra.

---

## Correo semanal

El correo automático incluye:

| Sección | Contenido |
|---------|-----------|
| **Resumen para el comité** | Tabla (probabilidad, dirección, factor de riesgo, factor de alivio), rango de modelos y posicionamiento (renta variable, renta fija, crédito, coberturas) |
| **Resumen ejecutivo** | Cifra del ensamble, consenso y encuadre de la divergencia |
| **Indicadores clave** | Cuatro bloques (crecimiento, inflación, política, señales de mercado), dos frases cada uno |
| **Divergencia entre modelos** | Lectura de la curva: historial, tres factores estructurales (QE, demanda externa de Treasuries, Basilea III) y el juicio |
| **Lista de seguimiento** | Umbrales: el valor que cada indicador tendría que alcanzar para una probabilidad del 30 % o del 50 %, ordenados por cercanía |
| **Escenario adverso** | Clasificación de riesgo de cola, tres disparadores reales y coberturas según el nivel del ensamble |
| **Qué cambiaría la lectura** | Cinco umbrales fijos (`SPREAD` < −1 %, inflación subyacente < 1,5 %, vivienda −15 % interanual, solicitudes > 300.000, ensamble > 20 %) |
| **Vigencia de los datos** | Fecha de corte y series con rezago de publicación |

Siete gráficos incrustados: medidor de probabilidad, tendencia del ensamble, percentil de los indicadores, comparación de modelos, trayectorias, historia completa y umbrales de sensibilidad.

---

## Configuración

Todas las decisiones de modelado están en un solo bloque:

| Parámetro | Valor por defecto | Descripción |
|-----------|-------------------|-------------|
| `TARGET_DEFINITION` | `"point"` | `"point"` = recesión en el mes t+12; `"window"` = cualquier recesión entre t+1 y t+12 |
| `OBS_START` | `"1967-01-01"` | Fecha de inicio de la muestra |
| `MIN_WINDOW` | `120` | Tamaño mínimo de la ventana expansiva, en meses |
| `MAX_FEATURES_BIC` | `9` | Máximo de variables en la selección BIC |
| `THRESHOLD_WARNING` | `30` | Umbral de alerta (%) |
| `THRESHOLD_ELEVATED` | `50` | Umbral elevado (%) |

---

## Estructura del proyecto

```
Recession_Probability_Model/
├── Recession_Probability_Model.ipynb   # Cuaderno interactivo (Google Colab)
├── automation/
│   ├── daily_report.py                 # Estimación, gráficos y JSON de resumen
│   ├── generate_email.py              # Redacción con Groq y envío por Gmail
│   └── output/                        # Gráficos, resúmenes y correos generados
├── .github/workflows/
│   └── daily_recession_report.yml     # Programación semanal en GitHub Actions
├── ejecutar_local.ps1                 # Corrida local en Windows
├── requirements.txt
├── .gitignore
├── LICENSE                            # MIT
└── README.md
```

---

## Dependencias

| Paquete | Versión | Para qué sirve |
|---------|---------|----------------|
| `fredapi` | >= 0.5.0 | Acceso a los datos de FRED |
| `statsmodels` | >= 0.14 | Regresión probit, efectos marginales y resúmenes |
| `scikit-learn` | >= 1.3 | Evaluación con AUROC y puntuación de Brier |
| `matplotlib` | >= 3.7 | Gráficos |
| `pandas` | >= 2.0 | Manipulación de datos y alineación de series |
| `numpy` | >= 1.24 | Operaciones numéricas |
| `scipy` | >= 1.10 | Distribución y densidad normal del probit |
| `groq` | >= 0.30 | API de Groq para redactar el correo |

Instalación: `pip install -r requirements.txt`

---

## Métricas de evaluación

| Métrica | Qué mide |
|---------|----------|
| **AUROC** | Capacidad de discriminar (1,0 = perfecta, 0,5 = azar) |
| **Puntuación de Brier** | Error cuadrático medio de la probabilidad (más bajo, mejor) |
| **Pseudo R²** | Varianza explicada frente a un modelo de solo intercepto |
| **AIC** | Equilibrio entre ajuste y complejidad (penalización leve) |
| **BIC** | El mismo equilibrio con penalización más fuerte. Es el criterio de selección |

---

## Limitaciones conocidas

- Está entrenado con unos 6 episodios de recesión independientes. La muestra es corta para generalizar.
- Supone que las recesiones futuras se parecerán a las pasadas. Mecanismos nuevos (pandemias, shocks geopolíticos) pueden quedar fuera.
- El horizonte de 12 meses es largo. Dentro de esa ventana las condiciones pueden cambiar de forma material.
- FRED publica con rezago (1 a 3 meses). La última lectura puede describir la situación de hace uno o dos meses.
- El modelo asigna un coeficiente negativo a la inflación, propio de las recesiones por colapso de la demanda. Puede subestimar el riesgo de estanflación, cuando la inflación y la debilidad del crecimiento coinciden.
- La selección BIC es dentro de muestra. El conjunto óptimo puede ser otro en un régimen futuro.
- El modelo es un insumo entre varios. No es base única para decidir una asignación de cartera.

---

## Referencias

Los títulos se dejan en el idioma de publicación.

1. **Estrella, A. y Mishkin, F.S. (1998).** "Predicting U.S. Recessions: Financial Variables as Leading Indicators." *Review of Economics and Statistics*, 80(1), 45-61.

2. **Wright, J.H. (2006).** "The Yield Curve and Predicting Recessions." *Federal Reserve Board FEDS Working Paper* n.º 2006-07.

3. **Kauppi, H. y Saikkonen, P. (2008).** "Predicting U.S. Recessions with Dynamic Binary Response Models." *Review of Economics and Statistics*, 90(4), 777-791.

4. **Berge, T.J. (2014).** "Predicting Recessions with Leading Indicators: Model Averaging and Links to the Financial Crisis." Documento de trabajo del Federal Reserve Bank of Kansas City.

5. **Berge, T.J. y Jordà, Ò. (2011).** "Evaluating the Classification of Economic Activity into Recessions and Expansions." *American Economic Journal: Macroeconomics*.

6. **Federal Reserve Board, FEDS Notes (2018, 2019).** Evaluación comparada de seis modelos probit de recesión.

7. **Fed de Boston (2020).** Sobre la dispersión de las probabilidades de recesión según cómo se construya la variable dependiente.

8. **McCracken, M.W. y Ng, S. (2016).** "FRED-MD: A Monthly Database for Macroeconomic Research." *Journal of Business & Economic Statistics*, 34(4), 574-589.

9. **Sahm, C. (2019).** "Direct Stimulus Payments to Individuals." *Brookings Institution*. Presenta la regla de Sahm.

10. **Bellego, C. y Ferrara, L. (2009).** "Forecasting Euro Area Recessions Using Time-Varying Binary Response Models for Financial Variables." Documento de trabajo del BCE.

---

## Cómo contribuir

Las contribuciones son bienvenidas. Para extender el modelo:

1. Haz un fork del repositorio.
2. Crea una rama (`git checkout -b feature/tu-cambio`).
3. Modifica y prueba en local con `python automation/daily_report.py`.
4. Abre un pull request que diga qué cambió y por qué.

Aportes especialmente útiles:

- Especificaciones adicionales (probit dinámico, promedio bayesiano de modelos).
- Fuentes de datos distintas de FRED.
- Modelos de recesión para otras economías (zona euro, Reino Unido, Japón).
- Un tablero web para el informe semanal.

---

## Aviso

Este proyecto es solo para **estudio e investigación**. No es asesoría financiera, ni de inversión, ni una recomendación de comprar, vender o mantener ningún valor o instrumento. La salida del modelo no debe ser la única base de una decisión de inversión. Que haya anticipado recesiones en el pasado no garantiza que lo haga en el futuro. Los modelos económicos son inciertos y pueden fallar sin aviso, sobre todo en situaciones nuevas. Quienes mantienen el código no asumen responsabilidad por pérdidas derivadas de su uso. Antes de decidir, consulta a un asesor financiero calificado.

---

## Licencia

Licencia MIT. El detalle está en [LICENSE](LICENSE).

---

## Temas sugeridos para el repositorio

`recession` `macroeconomics` `probit` `yield-curve` `fred-api` `economic-forecasting` `recession-probability` `nber` `time-series` `python` `statsmodels` `groq` `github-actions`
