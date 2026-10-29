#set page(binding: auto)

#set bibliography(title: [References], style: "apa")

#show bibliography: it => {
  counter(heading).update(0)
  pagebreak()
  it
}