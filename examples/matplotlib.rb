# The following code was taken from the Matlab tutorial.
# https://matplotlib.org/gallery/pie_and_polar_charts/pie_features.html

require 'yadriggy/py'

# draw_pie() is a Python function.
def draw_pie(labels, sizes, explode)
  fig1, ax1 = plt.subplots()
  ax1.pie(sizes, explode=explode, labels=labels, autopct='%1.1f%%',
          shadow=True, startangle=90)
  ax1.axis('equal')
  plt.show()
end

def run()
  Yadriggy::Py::Import::import('matplotlib.pyplot').as(:plt)
  labels = 'Frogs', 'Hogs', 'Dogs', 'Logs'
  sizes = [15, 30, 45, 10]
  Yadriggy::Py::run do
    # The code in this block is Python code.
    ex = tuple(0, 0.1, 0, 0)
    draw_pie(labels, sizes, ex)
  end
end

run()
